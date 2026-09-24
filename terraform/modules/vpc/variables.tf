# Module: vpc — input variables.
# Spec: docs/technical-spec.md#vpc-network-design

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

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Dev uses 10.0.0.0/16, prod uses 10.1.0.0/16 (non-overlapping, to allow future peering)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "The vpc_cidr must be a valid IPv4 CIDR block, for example \"10.0.0.0/16\"."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per availability zone and in the same order as availability_zones."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two subnet CIDRs are required — EKS and the ALB both need two availability zones."
  }
}

variable "availability_zones" {
  description = "Availability zones for the public subnets, in the same order as public_subnet_cidrs."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required — EKS and the ALB both need two."
  }
}

variable "tags" {
  description = "Additional tags merged over the three required tags."
  type        = map(string)
  default     = {}
}
