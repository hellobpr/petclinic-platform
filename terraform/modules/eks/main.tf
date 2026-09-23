# Module: eks — placeholder created by PETPLAT-1.
# Implemented in epic E-3 (PETPLAT-12..17).
#
# Purpose: EKS cluster, cluster IAM roles, OIDC provider, and the managed node group.

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
