## -----------------------------------------------------------------------------
## Agent
## -----------------------------------------------------------------------------

variable "agent_name" {
  description = "Name of the Bedrock Agent."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,100}$", var.agent_name))
    error_message = "agent_name must be 1-100 characters: letters, numbers, hyphens, underscores."
  }
}

variable "agent_description" {
  type    = string
  default = "Managed by Terraform (bedrock-agent-wrapper module)."
}

variable "foundation_model" {
  description = "Bedrock foundation model ID/ARN used for agent orchestration (e.g. anthropic.claude-3-5-sonnet-20241022-v2:0)."
  type        = string
}

variable "instruction" {
  description = "Agent system instruction. Must be >= 40 characters per Bedrock API constraints."
  type        = string

  validation {
    condition     = length(var.instruction) >= 40
    error_message = "instruction must be at least 40 characters."
  }
}

variable "idle_session_ttl_seconds" {
  type    = number
  default = 900

  validation {
    condition     = var.idle_session_ttl_seconds >= 60 && var.idle_session_ttl_seconds <= 3600
    error_message = "idle_session_ttl_seconds must be between 60 and 3600."
  }
}

variable "agent_collaboration" {
  description = "Multi-agent collaboration mode for this agent: DISABLED, SUPERVISOR, or SUPERVISOR_ROUTER. Only set to SUPERVISOR(_ROUTER) if this agent will have collaborators associated via the collaborators variable."
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["DISABLED", "SUPERVISOR", "SUPERVISOR_ROUTER"], var.agent_collaboration)
    error_message = "agent_collaboration must be one of DISABLED, SUPERVISOR, SUPERVISOR_ROUTER."
  }
}

variable "collaborators" {
  description = <<-EOT
    Map of collaborator_key => { collaborator_name, instruction, agent_alias_arn, relay_conversation_history }
    describing the collaborator agents this (supervisor) agent may delegate to.
    Wired via the native aws_bedrockagent_agent_collaborator resource so the
    exact AWS multi-agent-collaboration API contract is used directly, rather
    than an approximation.
  EOT
  type = map(object({
    collaborator_name          = string
    instruction                = string
    agent_alias_arn             = string
    relay_conversation_history = optional(string, "TO_COLLABORATOR")
  }))
  default = {}
}

variable "create_alias" {
  type    = bool
  default = true
}

variable "alias_name" {
  type    = string
  default = "live"
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for agent/KB/Lambda encryption at rest. Null uses AWS-owned keys."
  type        = string
  default     = null
}

## -----------------------------------------------------------------------------
## Knowledge Base (OpenSearch Serverless, via aws-ia/bedrock/aws create_default_kb)
## -----------------------------------------------------------------------------

variable "create_knowledge_base" {
  type    = bool
  default = false
}

variable "kb_name" {
  type    = string
  default = "knowledge-base"
}

variable "kb_embedding_model_arn" {
  type    = string
  default = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
}

variable "kb_vector_dimension" {
  type    = number
  default = 1024

  validation {
    condition     = contains([256, 384, 512, 1024, 1536], var.kb_vector_dimension)
    error_message = "kb_vector_dimension must match the embedding model's supported output size."
  }
}

variable "kb_s3_data_source_arn" {
  description = "ARN of an existing S3 bucket to use as the knowledge base's data source. If null and create_knowledge_base = true, the wrapped module provisions its own default bucket."
  type        = string
  default     = null
}

variable "kb_chunking_strategy" {
  type    = string
  default = "FIXED_SIZE"

  validation {
    condition     = contains(["FIXED_SIZE", "NONE", "HIERARCHICAL", "SEMANTIC"], var.kb_chunking_strategy)
    error_message = "kb_chunking_strategy must be one of FIXED_SIZE, NONE, HIERARCHICAL, SEMANTIC."
  }
}

variable "kb_chunking_max_tokens" {
  type    = number
  default = 512
}

variable "kb_chunking_overlap_percentage" {
  type    = number
  default = 20
}

## -----------------------------------------------------------------------------
## Action Group (Lambda tool execution)
## -----------------------------------------------------------------------------

variable "create_action_group" {
  description = "Whether to provision a Lambda-backed action group for this agent."
  type        = bool
  default     = false
}

variable "action_group_name" {
  type    = string
  default = "agent-tools"
}

variable "action_group_description" {
  type    = string
  default = "Tool-execution action group backed by a least-privilege Lambda function."
}

variable "action_group_openapi_schema" {
  description = "OpenAPI 3.0 schema (as a Terraform object, will be jsonencode'd) describing the action group's callable functions."
  type        = any
  default     = null
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "lambda_timeout_seconds" {
  type    = number
  default = 30
}

variable "lambda_memory_mb" {
  type    = number
  default = 256
}

variable "lambda_source_dir" {
  description = "Path to the directory containing the action group Lambda's source code (zipped by the archive provider)."
  type        = string
  default     = null
}

variable "lambda_environment_variables" {
  type    = map(string)
  default = {}
}

## -----------------------------------------------------------------------------
## Guardrail
## -----------------------------------------------------------------------------

variable "create_guardrail" {
  type    = bool
  default = false
}

variable "guardrail_name" {
  type    = string
  default = "agent-guardrail"
}

variable "guardrail_blocked_input_message" {
  type    = string
  default = "This request was blocked by content safety policy."
}

variable "guardrail_blocked_output_message" {
  type    = string
  default = "The generated response was blocked by content safety policy."
}

variable "tags" {
  type    = map(string)
  default = {}
}
