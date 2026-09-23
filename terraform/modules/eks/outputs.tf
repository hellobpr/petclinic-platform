# Module: eks — outputs.
# IDs, ARNs, and endpoints needed by downstream modules are exported in epic E-3 (PETPLAT-12..17).

output "name_prefix" {
  description = "Resource name prefix used by this module."
  value       = local.name_prefix
}

output "tags" {
  description = "Effective tags applied by this module."
  value       = local.tags
}
