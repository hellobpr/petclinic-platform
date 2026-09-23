# Module: dns — placeholder created by PETPLAT-1.
# Implemented in epic E-6 (PETPLAT-28..32).
#
# Purpose: Route 53 hosted zone, records, and the ACM certificate.

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
