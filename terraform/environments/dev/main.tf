## -----------------------------------------------------------------------------
## Dev environment root module.
##
## Deliberately minimal: a single Bedrock Agent + OpenSearch Serverless
## Knowledge Base + Lambda action group, provisioned via the
## aws-ia/bedrock/aws wrapper -- no EKS, no multi-agent supervisor graph.
## This is the fast, cheap loop for iterating on agent instructions,
## knowledge base content, and action group tools before promoting the
## validated configuration into the full prod topology.
## -----------------------------------------------------------------------------

locals {
  environment = "dev"

  tags = merge(var.tags, {
    Environment = local.environment
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
    Project     = "bedrock-multi-agent-orchestration"
  })
}

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

module "agent" {
  source = "../../modules/bedrock-agent-wrapper"

  agent_name        = "assistant-agent-${local.environment}"
  agent_description = "Single-agent quickstart: knowledge base retrieval plus one action-group tool."
  foundation_model  = var.foundation_model
  instruction       = "You are a helpful assistant. Use the knowledge base to ground factual answers and the getOrderStatus tool for order lookups. Say so explicitly when information is not available."
  kms_key_arn       = var.kms_key_arn

  create_knowledge_base  = true
  kb_name                = "agent-kb-${local.environment}"
  kb_embedding_model_arn = var.embedding_model_arn
  kb_vector_dimension    = 1024
  kb_s3_data_source_arn  = aws_s3_bucket.kb_documents.arn
  kb_chunking_strategy   = "FIXED_SIZE"

  create_action_group      = true
  action_group_name        = "assistant-tools"
  action_group_description = "Order status lookup tool."
  action_group_openapi_schema = {
    openapi = "3.0.0"
    info = {
      title   = "Assistant Tools"
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

  create_guardrail = false

  tags = local.tags
}
