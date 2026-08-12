variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "deployment_role_arn" {
  description = "IAM role assumed by the CI/CD OIDC identity (or an operator) to deploy this environment."
  type        = string
}

variable "cost_center" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "foundation_model" {
  type    = string
  default = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "embedding_model_arn" {
  type    = string
  default = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
}

variable "kb_data_source_bucket_name" {
  description = "Name of the S3 bucket created to hold knowledge base source documents."
  type        = string
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN. Left null in dev by default to avoid extra per-key cost on a throwaway environment."
  type        = string
  default     = null
}
