output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "supervisor_agent_alias_arn" {
  description = "ARN to invoke for all end-user traffic entering the multi-agent graph."
  value       = module.agent_supervisor.alias_arn
}

output "research_agent_knowledge_base_id" {
  value = module.agent_research.knowledge_base_id
}

output "action_agent_lambda_arn" {
  value = module.agent_action.action_group_lambda_arn
}

output "gateway_irsa_role_arn" {
  description = "Annotate the gateway ServiceAccount with this ARN (eks.amazonaws.com/role-arn) via the Helm chart's serviceAccount.annotations value."
  value       = module.gateway_irsa.role_arn
}

output "kb_documents_bucket" {
  value = aws_s3_bucket.kb_documents.id
}
