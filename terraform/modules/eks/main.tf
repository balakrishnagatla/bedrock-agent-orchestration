## -----------------------------------------------------------------------------
## Thin wrapper around the community-standard terraform-aws-modules/eks/aws
## module (4,000+ GitHub stars; the de-facto industry standard for EKS on
## Terraform). We pin an explicit version and expose only the inputs this
## platform needs, so the org's EKS conventions live in one reviewable place
## instead of being re-derived by every consumer of this repo.
##
## Rather than re-implement cluster/node-group/OIDC wiring by hand, we defer
## to the upstream module for the parts of the EKS lifecycle (addon
## versioning, KMS envelope encryption, node group launch templates, OIDC
## provider creation for IRSA) that it already gets right and keeps current
## with EKS API changes across new Kubernetes versions.
## -----------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access ? var.endpoint_public_access_cidrs : ["0.0.0.0/0"]

  # Encrypt Kubernetes secrets at rest with a dedicated, module-managed KMS key.
  create_kms_key = true
  encryption_config = {
    resources = ["secrets"]
  }

  # Zero-trust: nobody is implicitly an admin. Access is granted explicitly
  # via aws_eks_access_entry / aws_eks_access_policy_association elsewhere.
  enable_cluster_creator_admin_permissions = false
  authentication_mode                      = "API"

  cloudwatch_log_group_retention_in_days = var.cluster_log_retention_days

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        "workload-type" = "agent-orchestrator-gateway"
      }

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }

  tags = var.tags
}
