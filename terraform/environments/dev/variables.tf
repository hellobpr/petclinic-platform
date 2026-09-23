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
