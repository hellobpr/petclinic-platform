# PETPLAT-5: Input variables for the prod root module.
# Spec: docs/technical-spec.md#general-project-parameters

variable "aws_region" {
  description = "AWS region for all resources in this environment."
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name. Drives resource naming (petclinic-{env}-{resource}) and the Environment tag."
  type        = string
  default     = "prod"

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

# --- Networking (PETPLAT-10) -----------------------------------------------
# Spec: docs/technical-spec.md#cidr-allocation

variable "vpc_cidr" {
  description = "CIDR block for the prod VPC. Non-overlapping with dev (10.0.0.0/16)."
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the prod public subnets, paired by index with availability_zones."
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}
