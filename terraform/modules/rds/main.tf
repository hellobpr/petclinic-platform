# Module: rds — placeholder created by PETPLAT-1.
# Implemented in epic E-5 (PETPLAT-22..27).
#
# Purpose: RDS MySQL instance, subnet group, and parameter group.

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
