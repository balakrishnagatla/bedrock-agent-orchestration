## -----------------------------------------------------------------------------
## Production environment root module.
##
## Composes: platform VPC lookup -> EKS (terraform-aws-modules/eks) -> IRSA
##           -> Bedrock multi-agent graph:
##                research-agent  (collaborator, aws-ia/bedrock/aws + KB)
##                action-agent    (collaborator, aws-ia/bedrock/aws + Lambda
##                                 action group)
##                supervisor-agent (native aws_bedrockagent_agent, routes to
##                                  both collaborators via
##                                  aws_bedrockagent_agent_collaborator)
##
## The EKS-hosted agent-orchestrator-gateway (see ../../../helm) is the only
## caller permitted to invoke the supervisor's alias, via IRSA -- no static
## AWS credentials exist anywhere in this stack.
## -----------------------------------------------------------------------------

locals {
  environment = "prod"

  tags = merge(var.tags, {
    Environment = local.environment
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
    Project     = "bedrock-multi-agent-orchestration"
  })
}

data "aws_vpc" "platform" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }

  tags = {
    Tier = var.private_subnet_tier_tag
  }
}

## -----------------------------------------------------------------------------
## EKS cluster hosting the agent-orchestrator-gateway (Helm-deployed)
## -----------------------------------------------------------------------------

module "eks" {
  source = "../../modules/eks"

  cluster_name           = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  vpc_id                 = data.aws_vpc.platform.id
  private_subnet_ids     = data.aws_subnets.private.ids
  endpoint_public_access = false
  node_instance_types    = var.node_instance_types
  node_desired_size      = var.node_desired_size
  node_min_size          = var.node_min_size
  node_max_size          = var.node_max_size
  cluster_log_retention_days = 365

  tags = local.tags
}

## -----------------------------------------------------------------------------
## S3 bucket holding the raw documents ingested into the research agent's
## knowledge base
## -----------------------------------------------------------------------------

resource "aws_s3_bucket" "kb_documents" {
  bucket = var.kb_data_source_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "kb_documents" {
  bucket = aws_s3_bucket.kb_documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb_documents" {
  bucket = aws_s3_bucket.kb_documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kb_documents" {
  bucket                  = aws_s3_bucket.kb_documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## -----------------------------------------------------------------------------
## Collaborator: research-agent -- Bedrock Agent + OpenSearch Serverless
## Knowledge Base, provisioned via the aws-ia/bedrock/aws wrapper.
## -----------------------------------------------------------------------------

module "agent_research" {
  source = "../../modules/bedrock-agent-wrapper"

  agent_name        = "research-agent-${local.environment}"
  agent_description = "Retrieves and synthesizes grounded answers from the knowledge base."
  foundation_model  = var.foundation_model
  instruction       = "You are a research specialist. Answer questions strictly using retrieved knowledge base content. Cite source documents and state explicitly when information is not found."
  kms_key_arn       = var.kms_key_arn

  create_knowledge_base  = true
  kb_name                = "agent-kb-${local.environment}"
  kb_embedding_model_arn = var.embedding_model_arn
  kb_vector_dimension    = 1024
  kb_s3_data_source_arn  = aws_s3_bucket.kb_documents.arn
  kb_chunking_strategy   = "FIXED_SIZE"

  create_action_group = false

  tags = local.tags
}

## -----------------------------------------------------------------------------
## Collaborator: action-agent -- Bedrock Agent + Lambda-backed action group
## for structured operational tasks.
## -----------------------------------------------------------------------------

module "agent_action" {
  source = "../../modules/bedrock-agent-wrapper"

  agent_name        = "action-agent-${local.environment}"
  agent_description = "Executes structured operational tasks via a registered action-group Lambda."
  foundation_model  = var.foundation_model
  instruction       = "You are an operations specialist. Use the available action group functions to execute requested tasks precisely, confirming parameters before any mutating action."
  kms_key_arn       = var.kms_key_arn

  create_knowledge_base = false

  create_action_group      = true
  action_group_name        = "operational-tools"
  action_group_description = "Order status and account lookup tools invoked on the operations team's behalf."
  action_group_openapi_schema = {
    openapi = "3.0.0"
    info = {
      title   = "Operational Tools"
      version = "1.0.0"
    }
    paths = {
      "/getOrderStatus" = {
        get = {
          summary     = "Get the current status of an order"
          operationId = "getOrderStatus"
          parameters = [
            {
              name     = "orderId"
              "in"     = "query"
              required = true
              schema   = { type = "string" }
            }
          ]
          responses = {
            "200" = { description = "Order status returned successfully" }
          }
        }
      }
    }
  }

  tags = local.tags
}

## -----------------------------------------------------------------------------
## Supervisor: routes user intent to the research-agent or action-agent.
## Native multi-agent-collaboration resources -- see modules/bedrock-supervisor.
## -----------------------------------------------------------------------------

module "agent_supervisor" {
  source = "../../modules/bedrock-supervisor"

  agent_name          = "supervisor-agent-${local.environment}"
  foundation_model    = var.foundation_model
  instruction         = "You are the orchestration supervisor. Classify each incoming request and delegate to the research-agent for informational queries or the action-agent for operational tasks. Never answer directly if a collaborator is better suited."
  agent_collaboration = "SUPERVISOR"
  kms_key_arn         = var.kms_key_arn
  guardrail_id        = var.guardrail_id

  collaborators = {
    research = {
      collaborator_name = "research-agent"
      instruction        = "Delegate any informational or knowledge-lookup request to this collaborator."
      agent_alias_arn    = module.agent_research.alias_arn
    }
    action = {
      collaborator_name = "action-agent"
      instruction        = "Delegate any operational or task-execution request to this collaborator."
      agent_alias_arn    = module.agent_action.alias_arn
    }
  }

  tags = local.tags
}

## -----------------------------------------------------------------------------
## IRSA: EKS-hosted agent-orchestrator-gateway may invoke only the
## supervisor's stable alias -- least privilege, no static credentials.
## -----------------------------------------------------------------------------

module "gateway_irsa" {
  source = "../../modules/irsa"

  role_name             = "${var.cluster_name}-gateway-irsa"
  oidc_provider_arn     = module.eks.oidc_provider_arn
  namespace             = var.gateway_namespace
  service_account_name  = var.gateway_service_account_name
  agent_alias_arns      = [module.agent_supervisor.alias_arn]

  tags = local.tags
}
