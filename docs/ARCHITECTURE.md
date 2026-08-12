# Architecture Deep-Dive

See the [README](../README.md) for the high-level diagram and quick start.
This document covers the decisions the diagram doesn't show.

## Request path

1. A client calls the `agent-orchestrator-gateway` Service on EKS (internal
   ALB / API Gateway VPC Link in front of it, not included in this repo --
   see "What's intentionally out of scope" below).
2. The gateway pod, running under its IRSA-bound ServiceAccount, calls
   `bedrock:InvokeAgent` against the **supervisor agent's alias ARN only**.
   The IAM policy scopes this to that one ARN -- the pod cannot invoke the
   research-agent or action-agent directly, and cannot invoke any other
   account's agents.
3. The supervisor agent (native `aws_bedrockagent_agent`, `agent_collaboration
   = SUPERVISOR`) classifies intent and, via `aws_bedrockagent_agent_collaborator`
   associations, delegates to:
   - **research-agent**: queries the OpenSearch Serverless-backed knowledge
     base (`bedrock:Retrieve` / `RetrieveAndGenerate`) for grounded answers.
   - **action-agent**: invokes its Lambda action group for operational
     tasks (e.g. order status lookups).
4. Each agent's execution role is scoped to exactly what that agent needs --
   see `docs/adr/` and the module `variables.tf` files for the specific IAM
   statements.

## Why a community module wrapper instead of hand-rolled resources

`terraform/modules/bedrock-agent-wrapper` wraps `aws-ia/bedrock/aws` (AWS's
own Integration & Automation team module) for the well-documented
single-agent + knowledge base + action group + guardrail surface, and
`terraform/modules/eks` wraps `terraform-aws-modules/eks/aws` for cluster
provisioning. Multi-agent supervisor/collaborator wiring
(`terraform/modules/bedrock-supervisor`) uses the native AWS provider
resources directly instead, because that specific API surface
(`agent_collaboration`, `aws_bedrockagent_agent_collaborator`) is precisely
documented in the `hashicorp/aws` provider docs, while the community
module's collaborator variables were not stable/documented enough at the
version pinned here to trust without direct verification. Re-evaluate this
split as the upstream module matures past 1.0.

## What's intentionally out of scope

This repo is a reference pattern, not a full landing zone. It assumes:

- **A VPC already exists** (looked up via `data "aws_vpc"` / `data
  "aws_subnets"` by tag) -- provisioned by a separate foundational stack,
  e.g. [`aws-samples/aws-startup-landing-zone-terraform-example`](https://github.com/aws-samples/aws-startup-landing-zone-terraform-example)
  or an internal landing-zone module. Baking VPC/NAT/multi-account setup
  into an application-layer repo makes both harder to review independently.
- **No ingress layer** (ALB, API Gateway, WAF) is defined for the gateway
  Service -- that's a platform-wide concern usually shared across many
  workloads on the same cluster, not owned per-application.
- **No Karpenter / cluster autoscaler** is wired up. For a
  production EKS platform with many workloads, adopt
  [`aws-ia/terraform-aws-eks-blueprints`](https://github.com/aws-ia/terraform-aws-eks-blueprints)
  as the cluster-platform layer underneath workloads like this one, or add
  Karpenter directly.

## Cost notes

- **OpenSearch Serverless**: billed in OCUs (indexing + search), 2 OCU
  minimum for a collection with redundancy. This is the dominant recurring
  cost in `dev`. Delete the `dev` collection when not actively iterating.
- **EKS**: control plane is a fixed hourly cost regardless of node count;
  the managed node group is the variable cost. `dev` does not provision
  EKS at all for this reason (see `terraform/environments/dev`).
- **Bedrock model invocation**: usage-based, billed per input/output token;
  not a Terraform-managed cost but the largest one at real traffic volumes.
- See the README's Cost & Cleanup section for `terraform destroy` ordering.
