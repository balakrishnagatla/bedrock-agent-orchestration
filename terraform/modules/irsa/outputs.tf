output "role_arn" {
  description = "IAM role ARN to annotate on the Kubernetes ServiceAccount (eks.amazonaws.com/role-arn)."
  value       = module.irsa.iam_role_arn
}

output "role_name" {
  description = "IAM role name."
  value       = module.irsa.iam_role_name
}
