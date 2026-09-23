# Module: observability — placeholder created by PETPLAT-1.
# Implemented in epic E-11 (PETPLAT-55..60).
#
# Purpose: CloudWatch log groups, alarms, and supporting observability resources.

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
