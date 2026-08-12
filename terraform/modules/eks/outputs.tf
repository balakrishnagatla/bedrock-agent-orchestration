output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN, consumed by the irsa module to build IRSA trust policies."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "IAM OIDC provider issuer URL without the https:// prefix."
  value       = module.eks.oidc_provider
}

output "node_security_group_id" {
  description = "Security group ID shared by the node group."
  value       = module.eks.node_security_group_id
}
