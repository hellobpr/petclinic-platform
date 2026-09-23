# Module: observability — outputs.
# IDs, ARNs, and endpoints needed by downstream modules are exported in epic E-11 (PETPLAT-55..60).

output "name_prefix" {
  description = "Resource name prefix used by this module."
  value       = local.name_prefix
}

output "tags" {
  description = "Effective tags applied by this module."
  value       = local.tags
}
