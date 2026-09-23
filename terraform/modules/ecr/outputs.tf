# Module: ecr — outputs.
# IDs, ARNs, and endpoints needed by downstream modules are exported in epic E-4 (PETPLAT-18..21).

output "name_prefix" {
  description = "Resource name prefix used by this module."
  value       = local.name_prefix
}

output "tags" {
  description = "Effective tags applied by this module."
  value       = local.tags
}
