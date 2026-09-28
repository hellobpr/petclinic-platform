# PETPLAT-5: Input variables for the dev root module.
# Spec: docs/technical-spec.md#general-project-parameters

variable "aws_region" {
  description = "AWS region for all resources in this environment."
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name. Drives resource naming (petclinic-{env}-{resource}) and the Environment tag."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either \"dev\" or \"prod\"."
  }
}

variable "project" {
  description = "Project name. Used as the resource name prefix and the Project tag."
  type        = string
  default     = "petclinic"
}

variable "availability_zones" {
  description = "Availability zones used by subnets in this environment."
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

# --- Networking (PETPLAT-9) ------------------------------------------------
# Spec: docs/technical-spec.md#cidr-allocation

variable "vpc_cidr" {
  description = "CIDR block for the dev VPC. Non-overlapping with prod (10.1.0.0/16)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the dev public subnets, paired by index with availability_zones."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# --- EKS (PETPLAT-15) ------------------------------------------------------
# Spec: docs/technical-spec.md#eks-cluster

variable "kubernetes_version" {
  description = "Kubernetes version for the dev cluster."
  type        = string
  default     = "1.35"
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to reach the dev API server endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_node_instance_types" {
  description = "Instance types for the dev node group. ARM64/Graviton free trial."
  type        = list(string)
  default     = ["t4g.small"]
}

variable "eks_node_min_size" {
  description = "Minimum node count for dev."
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum node count for dev."
  type        = number
  default     = 4
}

variable "eks_node_desired_size" {
  description = "Desired node count for dev at creation."
  type        = number
  default     = 2
}

variable "eks_node_disk_size" {
  description = "Root EBS volume size per dev node, in GB."
  type        = number
  default     = 20
}

variable "eks_cluster_admin_principals" {
  description = "Additional IAM user/role ARNs granted cluster-admin on dev. The apply principal is already admin."
  type        = list(string)
  default     = []
}
