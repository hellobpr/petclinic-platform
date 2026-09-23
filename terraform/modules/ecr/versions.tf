# Module: ecr — provider constraints.
# Spec: docs/technical-spec.md#general-project-parameters

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
