# Module: ecr — placeholder created by PETPLAT-1.
# Implemented in epic E-4 (PETPLAT-18..21).
#
# Purpose: ECR repositories for the 8 services, with scan-on-push and lifecycle policies.

locals {
  name_prefix = "${var.project}-${var.environment}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}
