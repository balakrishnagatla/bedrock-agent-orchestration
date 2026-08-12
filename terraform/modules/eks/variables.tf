variable "cluster_name" {
  description = "Name of the EKS cluster that hosts the agent-orchestrator-gateway workload."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,99}$", var.cluster_name))
    error_message = "cluster_name must start with a letter and contain only alphanumerics and hyphens (max 100 chars)."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (major.minor)."
  type        = string
  default     = "1.30"

  validation {
    condition     = can(regex("^1\\.(2[8-9]|3[0-9])$", var.kubernetes_version))
    error_message = "kubernetes_version must be a supported EKS minor version (>= 1.28)."
  }
}

variable "vpc_id" {
  description = "VPC ID in which to deploy the EKS cluster and managed node group."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes and (optionally) control plane ENIs."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets across different AZs are required for EKS control plane HA."
  }
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server endpoint is reachable from the public internet. Disabled by default for a zero-trust posture; use a bastion/VPN/Cloud9 in-VPC instead."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint, if enabled."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "EC2 instance types for the default managed node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_capacity_type" {
  description = "Capacity type for worker nodes: ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "cluster_log_retention_days" {
  description = "CloudWatch Logs retention for the EKS control plane log group created by the upstream module."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
