output "agent_id" {
  description = "Bedrock Agent ID."
  value       = module.bedrock.bedrock_agent.agent_id
}

output "agent_arn" {
  description = "Bedrock Agent ARN."
  value       = module.bedrock.bedrock_agent.agent_arn
}

output "alias_id" {
  description = "Stable agent alias ID, if created."
  value       = try(module.bedrock.bedrock_agent_alias.agent_alias_id, null)
}

output "alias_arn" {
  description = "Stable agent alias ARN -- this is the identifier collaborators/gateways invoke, never the raw agent_id."
  value        = try(module.bedrock.bedrock_agent_alias.agent_alias_arn, null)
}

output "execution_role_arn" {
  description = "IAM role ARN assumed by the Bedrock Agent at runtime."
  value       = module.bedrock.agent_resource_role_arn
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID (OpenSearch Serverless-backed), if created."
  value       = var.create_knowledge_base ? module.bedrock.default_kb_identifier : null
}

output "opensearch_collection" {
  description = "Underlying OpenSearch Serverless collection object, if a knowledge base was created."
  value       = var.create_knowledge_base ? module.bedrock.default_collection : null
}

output "action_group_lambda_arn" {
  description = "ARN of the provisioned action-group Lambda function, if created."
  value       = var.create_action_group ? aws_lambda_function.action_group[0].arn : null
}
