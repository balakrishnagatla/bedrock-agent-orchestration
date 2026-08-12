## -----------------------------------------------------------------------------
## Native-resource supervisor agent.
##
## The multi-agent-collaboration surface (agent_collaboration on
## aws_bedrockagent_agent + aws_bedrockagent_agent_collaborator) is used
## directly rather than through the community wrapper module: it is a small,
## precisely-documented API contract in the AWS provider, and a supervisor
## has no knowledge base or action group of its own -- wrapping it would add
## indirection without benefit.
## -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowBedrockAgentAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agent/*"]
    }
  }
}

resource "aws_iam_role" "supervisor" {
  name               = "bedrock-supervisor-${var.agent_name}"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "InvokeFoundationModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.foundation_model}"]
  }

  statement {
    sid       = "InvokeCollaboratorAgentAliases"
    effect    = "Allow"
    actions   = ["bedrock:InvokeAgent"]
    resources = [for c in var.collaborators : c.agent_alias_arn]
  }

  dynamic "statement" {
    for_each = var.guardrail_id != null ? [1] : []
    content {
      sid       = "ApplyGuardrail"
      effect    = "Allow"
      actions   = ["bedrock:ApplyGuardrail"]
      resources = ["arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:guardrail/${var.guardrail_id}"]
    }
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid       = "UseCustomerManagedKey"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "permissions" {
  name   = "bedrock-supervisor-${var.agent_name}-permissions"
  role   = aws_iam_role.supervisor.id
  policy = data.aws_iam_policy_document.permissions.json
}

resource "aws_bedrockagent_agent" "supervisor" {
  agent_name                  = var.agent_name
  agent_resource_role_arn     = aws_iam_role.supervisor.arn
  description                 = var.agent_description
  foundation_model             = var.foundation_model
  instruction                  = var.instruction
  idle_session_ttl_in_seconds  = var.idle_session_ttl_seconds
  agent_collaboration          = var.agent_collaboration
  prepare_agent                = false # prepared explicitly below, after collaborators are attached
  customer_encryption_key_arn  = var.kms_key_arn

  dynamic "guardrail_configuration" {
    for_each = var.guardrail_id != null ? [1] : []
    content {
      guardrail_identifier = var.guardrail_id
      guardrail_version    = var.guardrail_version
    }
  }

  tags = merge(var.tags, { AgentRole = "supervisor" })
}

resource "aws_bedrockagent_agent_collaborator" "this" {
  for_each = var.collaborators

  agent_id                    = aws_bedrockagent_agent.supervisor.agent_id
  collaborator_name           = each.value.collaborator_name
  collaboration_instruction   = each.value.instruction
  relay_conversation_history  = each.value.relay_conversation_history
  prepare_agent                = true

  agent_descriptor {
    alias_arn = each.value.agent_alias_arn
  }
}

resource "aws_bedrockagent_agent_alias" "this" {
  count = var.create_alias ? 1 : 0

  agent_id         = aws_bedrockagent_agent.supervisor.agent_id
  agent_alias_name = var.alias_name
  description      = "Stable alias for supervisor agent ${var.agent_name}"
  tags             = var.tags

  depends_on = [aws_bedrockagent_agent_collaborator.this]
}
