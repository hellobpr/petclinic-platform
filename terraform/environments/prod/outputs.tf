# PETPLAT-1: Outputs for the prod root module.
#
# Module outputs (vpc_id, eks_cluster_endpoint, rds_endpoint, ecr_repository_urls, ...)
# are added as each epic lands.

output "aws_account_id" {
  description = "AWS account ID this environment is deployed into."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region this environment is deployed into."
  value       = data.aws_region.current.name
}

output "environment" {
  description = "Environment name."
  value       = var.environment
}

output "name_prefix" {
  description = "Resource name prefix used across this environment."
  value       = local.name_prefix
}
