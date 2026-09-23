# Module: vpc — placeholder created by PETPLAT-1.
# Implemented in epic E-2 (PETPLAT-6..11).
#
# Purpose: VPC, public subnets across 2 AZs, Internet Gateway, and baseline security groups.

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
