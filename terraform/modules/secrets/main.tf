# Module: secrets — placeholder created by PETPLAT-1.
# Implemented in epic E-7 (PETPLAT-33..37).
#
# Purpose: Secrets Manager secrets and the IRSA role for External Secrets Operator.

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
