data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  lambda_source_dir = coalesce(var.lambda_source_dir, "${path.module}/lambda_src")
}

## -----------------------------------------------------------------------------
## Action Group Lambda: least-privilege execution role scoped to its own log
## group only, plus optional KMS decrypt for environment variable encryption.
## -----------------------------------------------------------------------------

data "archive_file" "action_group_lambda" {
  count = var.create_action_group ? 1 : 0

  type        = "zip"
  source_dir  = local.lambda_source_dir
  output_path = "${path.module}/.build/${var.agent_name}-action-group.zip"
}

data "aws_iam_policy_document" "lambda_trust" {
  count = var.create_action_group ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  count = var.create_action_group ? 1 : 0

  name               = "${var.agent_name}-action-group-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust[0].json
  tags               = var.tags
}

resource "aws_cloudwatch_log_group" "action_group_lambda" {
  count = var.create_action_group ? 1 : 0

  name              = "/aws/lambda/${var.agent_name}-action-group"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "lambda_permissions" {
  count = var.create_action_group ? 1 : 0

  statement {
    sid    = "WriteOwnLogGroupOnly"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.action_group_lambda[0].arn}:*"]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid       = "DecryptEnvironmentVariables"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  count = var.create_action_group ? 1 : 0

  name   = "${var.agent_name}-action-group-lambda-permissions"
  role   = aws_iam_role.lambda_execution[0].id
  policy = data.aws_iam_policy_document.lambda_permissions[0].json
}

resource "aws_lambda_function" "action_group" {
  count = var.create_action_group ? 1 : 0

  function_name    = "${var.agent_name}-action-group"
  role             = aws_iam_role.lambda_execution[0].arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb
  filename         = data.archive_file.action_group_lambda[0].output_path
  source_code_hash = data.archive_file.action_group_lambda[0].output_base64sha256
  kms_key_arn      = var.kms_key_arn

  dynamic "environment" {
    for_each = length(var.lambda_environment_variables) > 0 ? [1] : []
    content {
      variables = var.lambda_environment_variables
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.action_group_lambda]
}

# Bedrock may invoke this function ONLY on behalf of the agent created below
# (source_arn condition), not from any other caller in the account.
resource "aws_lambda_permission" "allow_bedrock_invoke" {
  count = var.create_action_group ? 1 : 0

  statement_id  = "AllowBedrockAgentInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.action_group[0].function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agent/*"
}

## -----------------------------------------------------------------------------
## Bedrock Agent + Knowledge Base + Action Group + Guardrail
##
## Delegated to the AWS-maintained community module (aws-ia/bedrock/aws) for
## the well-documented single-agent surface: agent lifecycle, OpenSearch
## Serverless-backed knowledge base provisioning, action group wiring, and
## guardrail policy configuration. Pin the version explicitly -- this module
## is still < 1.0.0, so treat every minor bump as a breaking-change review,
## not an auto-upgrade.
## -----------------------------------------------------------------------------

module "bedrock" {
  source  = "aws-ia/bedrock/aws"
  version = ">= 0.0.16, < 0.1.0"

  # --- Agent ---
  create_agent      = true
  agent_name        = var.agent_name
  agent_description = var.agent_description
  foundation_model  = var.foundation_model
  instruction       = var.instruction
  idle_session_ttl  = var.idle_session_ttl_seconds
  kms_key_arn       = var.kms_key_arn
  tags              = var.tags

  create_agent_alias = var.create_alias
  agent_alias_name   = var.alias_name

  # --- Knowledge Base (OpenSearch Serverless "default" express path) ---
  create_kb          = var.create_knowledge_base
  create_default_kb  = var.create_knowledge_base
  kb_name            = var.kb_name
  kb_type            = "VECTOR"
  kb_description     = "Vector knowledge base for agent ${var.agent_name}, managed by Terraform."
  kb_embedding_model_arn = var.kb_embedding_model_arn
  vector_dimension   = var.kb_vector_dimension

  create_opensearch_config = var.create_knowledge_base

  create_s3_data_source = var.create_knowledge_base
  kb_s3_data_source      = var.kb_s3_data_source_arn

  create_vector_ingestion_configuration = var.create_knowledge_base
  chunking_strategy                     = var.kb_chunking_strategy
  chunking_strategy_max_tokens          = var.kb_chunking_max_tokens
  chunking_strategy_overlap_percentage  = var.kb_chunking_overlap_percentage

  # --- Action Group ---
  create_ag                 = var.create_action_group
  action_group_name         = var.action_group_name
  action_group_description  = var.action_group_description
  action_group_state        = "ENABLED"
  lambda_action_group_executor = var.create_action_group ? aws_lambda_function.action_group[0].arn : null
  api_schema_payload = var.action_group_openapi_schema != null ? jsonencode(var.action_group_openapi_schema) : null

  # --- Guardrail ---
  create_guardrail           = var.create_guardrail
  guardrail_name             = var.guardrail_name
  guardrail_description      = "Content-safety guardrail for agent ${var.agent_name}, managed by Terraform."
  blocked_input_messaging    = var.guardrail_blocked_input_message
  blocked_outputs_messaging  = var.guardrail_blocked_output_message
  guardrail_kms_key_arn      = var.kms_key_arn

  filters_config = var.create_guardrail ? [
    { type = "HATE", input_strength = "HIGH", output_strength = "HIGH" },
    { type = "INSULTS", input_strength = "HIGH", output_strength = "HIGH" },
    { type = "SEXUAL", input_strength = "HIGH", output_strength = "HIGH" },
    { type = "VIOLENCE", input_strength = "HIGH", output_strength = "HIGH" },
    { type = "MISCONDUCT", input_strength = "HIGH", output_strength = "HIGH" },
    { type = "PROMPT_ATTACK", input_strength = "HIGH", output_strength = "NONE" },
  ] : null

  depends_on = [aws_lambda_permission.allow_bedrock_invoke]
}
