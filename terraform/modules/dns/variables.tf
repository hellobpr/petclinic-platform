# Module: dns — input variables.
# Resource-specific variables are added in epic E-6 (PETPLAT-28..32).

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

variable "tags" {
  description = "Additional tags merged over the three required tags."
  type        = map(string)
  default     = {}
}
