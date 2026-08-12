## -----------------------------------------------------------------------------
## Least-privilege IAM policy: invoke exactly the supplied Bedrock agent
## alias ARNs, nothing else. Kept as a plain resource (not the module) so the
## permission surface is explicit and easy to diff in PR review.
## -----------------------------------------------------------------------------

resource "aws_iam_policy" "invoke_agents" {
  name        = "${var.role_name}-invoke-agents"
  description = "Least-privilege bedrock:InvokeAgent scoped to the orchestrator gateway's agent aliases."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeBedrockAgentAliases"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeAgent"]
        Resource = var.agent_alias_arns
      },
      {
        Sid    = "PublishGatewayObservability"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AgentOrchestrator/Gateway"
          }
        }
      }
    ]
  })

  tags = var.tags
}

## -----------------------------------------------------------------------------
## Thin wrapper around the community-standard IRSA submodule
## (terraform-aws-modules/iam//modules/iam-role-for-service-accounts-eks).
## It builds the exact-match OIDC federated trust policy
## (aud=sts.amazonaws.com, sub=system:serviceaccount:<ns>:<sa>) so a pod can
## assume this role only via its own projected service account token --
## no static credentials, no wildcard trust.
## -----------------------------------------------------------------------------

module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.48"

  role_name = var.role_name

  role_policy_arns = {
    invoke_agents = aws_iam_policy.invoke_agents.arn
  }

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account_name}"]
    }
  }

  tags = var.tags
}
