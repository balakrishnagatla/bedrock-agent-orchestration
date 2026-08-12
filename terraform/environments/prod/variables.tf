variable "aws_region" {
  description = "AWS region for all prod resources."
  type        = string
  default     = "us-east-1"
}

variable "deployment_role_arn" {
  description = "IAM role assumed by the CI/CD OIDC identity (or an operator) to deploy this environment."
  type        = string
}

variable "cost_center" {
  description = "Cost center / billing code applied as a tag for chargeback reporting."
  type        = string
}

variable "tags" {
  description = "Additional free-form tags merged with the standard tagging strategy."
  type        = map(string)
  default     = {}
}

## --- Networking (foundational VPC is owned by a separate landing-zone stack) ---

variable "vpc_name" {
  description = "Name tag of the pre-existing platform VPC to deploy into."
  type        = string
}

variable "private_subnet_tier_tag" {
  description = "Value of the 'Tier' tag identifying private subnets within the VPC."
  type        = string
  default     = "private"
}

## --- EKS ---

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "agent-orchestration-prod"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large", "m6i.xlarge"]
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 9
}

## --- Bedrock Knowledge Base ---

variable "embedding_model_arn" {
  description = "Bedrock embedding model ARN used to vectorize documents."
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
}

variable "kb_data_source_bucket_name" {
  description = "Name of the S3 bucket created to hold knowledge base source documents."
  type        = string
}

## --- Bedrock Agents ---

variable "foundation_model" {
  description = "Foundation model used by every agent in the orchestration graph."
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "guardrail_id" {
  description = "Optional Bedrock Guardrail ID applied to all agents."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN used across Bedrock, EKS, and OpenSearch Serverless encryption."
  type        = string
  default     = null
}

## --- Kubernetes / Helm ---

variable "gateway_namespace" {
  description = "Kubernetes namespace for the agent-orchestrator-gateway Helm release."
  type        = string
  default     = "agent-orchestrator"
}

variable "gateway_service_account_name" {
  description = "Kubernetes service account name used by the gateway deployment (must match helm values.yaml serviceAccount.name)."
  type        = string
  default     = "agent-orchestrator-gateway"
}
