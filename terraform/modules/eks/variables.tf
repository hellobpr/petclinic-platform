# Module: eks — input variables.
# Spec: docs/technical-spec.md#eks-cluster

variable "project" {
  description = "Project name. Used as the resource name prefix and the Project tag."
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev or prod)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either \"dev\" or \"prod\"."
  }
}

# --- Networking (from the vpc module) --------------------------------------

variable "subnet_ids" {
  description = "Public subnet IDs for the cluster and node group. Pass module.vpc.subnet_ids."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "cluster_security_group_id" {
  description = "Security group for the control plane. Pass module.vpc.eks_cluster_security_group_id."
  type        = string
}

variable "node_security_group_id" {
  description = "Security group for the worker nodes. Pass module.vpc.eks_node_security_group_id."
  type        = string
}

# --- Cluster ---------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version. Must be a version EKS currently offers for new clusters — check with `aws eks describe-cluster-versions`. 1.29 from the original spec is no longer available."
  type        = string
  default     = "1.35"
}

variable "cluster_log_types" {
  description = "Control-plane log types to ship to CloudWatch Logs."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API server endpoint. Defaults to open because CI and kubectl come from dynamic addresses; narrow this if you have fixed egress IPs."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_admin_principals" {
  description = "Additional IAM user/role ARNs granted cluster-admin via EKS access entries. The apply principal is already admin via bootstrap permissions."
  type        = list(string)
  default     = []
}

# --- Node group ------------------------------------------------------------

variable "node_instance_types" {
  description = "Instance types for the managed node group. t4g.small is ARM64/Graviton, covered by the free trial until Dec 2026."
  type        = list(string)
  default     = ["t4g.small"]
}

variable "node_ami_type" {
  description = "AMI type. Must match the instance architecture. AL2023_ARM_64_STANDARD for Graviton; the spec's original AL2_ARM_64 is unavailable past Kubernetes 1.32."
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT. Karpenter introduces spot capacity in E-14."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "The node_capacity_type must be either \"ON_DEMAND\" or \"SPOT\"."
  }
}

variable "node_disk_size" {
  description = "Root EBS volume size per node, in GB. 20 GB x 2 nodes fits the 30 GB EBS free tier."
  type        = number
  default     = 20
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired node count at creation. Ignored on subsequent applies so autoscalers can own it."
  type        = number
  default     = 2
}

variable "node_labels" {
  description = "Extra Kubernetes labels for nodes, merged over environment and managed-by."
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Kubernetes taints for nodes."
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string
  }))
  default = []

  validation {
    condition = alltrue([
      for t in var.node_taints :
      contains(["NO_SCHEDULE", "NO_EXECUTE", "PREFER_NO_SCHEDULE"], t.effect)
    ])
    error_message = "Each taint effect must be NO_SCHEDULE, NO_EXECUTE or PREFER_NO_SCHEDULE."
  }
}

# --- Add-ons ---------------------------------------------------------------

variable "addon_versions" {
  description = "Pinned EKS managed add-on versions. Defaults are the EKS defaults for Kubernetes 1.35; refresh them if kubernetes_version changes (see addons.tf for the command)."
  type = object({
    vpc_cni            = string
    kube_proxy         = string
    coredns            = string
    aws_ebs_csi_driver = string
  })
  default = {
    vpc_cni            = "v1.22.4-eksbuild.3"
    kube_proxy         = "v1.35.3-eksbuild.29"
    coredns            = "v1.13.2-eksbuild.31"
    aws_ebs_csi_driver = "v1.66.0-eksbuild.1"
  }
}

variable "tags" {
  description = "Additional tags merged over the three required tags."
  type        = map(string)
  default     = {}
}
