# PETPLAT-1: Outputs for the dev root module.
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

# --- Networking (PETPLAT-9) ------------------------------------------------

output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the dev VPC."
  value       = module.vpc.vpc_cidr
}

output "subnet_ids" {
  description = "IDs of the dev public subnets."
  value       = module.vpc.subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the dev Internet Gateway."
  value       = module.vpc.internet_gateway_id
}

output "security_group_ids" {
  description = "Dev security group IDs, keyed by role."
  value       = module.vpc.security_group_ids
}
