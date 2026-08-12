output "agent_id" {
  value = module.agent.agent_id
}

output "agent_alias_arn" {
  value = module.agent.alias_arn
}

output "knowledge_base_id" {
  value = module.agent.knowledge_base_id
}

output "action_group_lambda_arn" {
  value = module.agent.action_group_lambda_arn
}

output "kb_documents_bucket" {
  value = aws_s3_bucket.kb_documents.id
}
