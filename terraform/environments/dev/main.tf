# PETPLAT-1 / PETPLAT-5: dev root module.
#
# Module calls are added as each epic lands:
#   E-2 vpc, E-3 eks, E-4 ecr, E-5 rds, E-6 dns, E-7 secrets, E-11 observability

locals {
  # Resource name prefix: petclinic-dev-{resource}
  name_prefix = "${var.project}-${var.environment}"

  # The three tags required on every AWS resource.
  # Spec: docs/technical-spec.md#required-tags-all-aws-resources
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
