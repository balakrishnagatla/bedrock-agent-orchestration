output "agent_id" {
  value = aws_bedrockagent_agent.supervisor.agent_id
}

output "agent_arn" {
  value = aws_bedrockagent_agent.supervisor.agent_arn
}

output "alias_id" {
  value = try(aws_bedrockagent_agent_alias.this[0].agent_alias_id, null)
}

output "alias_arn" {
  description = "Entry point ARN for all end-user traffic into the multi-agent graph."
  value       = try(aws_bedrockagent_agent_alias.this[0].agent_alias_arn, null)
}

output "execution_role_arn" {
  value = aws_iam_role.supervisor.arn
}
