variable "role_name" {
  description = "Name of the IAM role assumed by the Kubernetes service account (IRSA)."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (from the eks module's oidc_provider_arn output)."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account permitted to assume this role."
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name permitted to assume this role."
  type        = string
}

variable "agent_alias_arns" {
  description = "Bedrock agent alias ARNs the gateway service account is permitted to invoke."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
