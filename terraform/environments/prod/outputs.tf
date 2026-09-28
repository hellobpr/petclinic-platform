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

# --- Networking (PETPLAT-10) -----------------------------------------------

output "vpc_id" {
  description = "ID of the prod VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the prod VPC."
  value       = module.vpc.vpc_cidr
}

output "subnet_ids" {
  description = "IDs of the prod public subnets."
  value       = module.vpc.subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the prod Internet Gateway."
  value       = module.vpc.internet_gateway_id
}

output "security_group_ids" {
  description = "Prod security group IDs, keyed by role."
  value       = module.vpc.security_group_ids
}

# --- EKS (PETPLAT-17) ------------------------------------------------------

output "cluster_name" {
  description = "Name of the prod EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Prod Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA data for the prod cluster."
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the prod cluster."
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "ARN of the prod IAM OIDC provider, for IRSA trust policies."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "Prod OIDC issuer URL without scheme."
  value       = module.eks.oidc_provider_url
}

output "node_group_name" {
  description = "Name of the prod managed node group."
  value       = module.eks.node_group_name
}

output "node_role_arn" {
  description = "ARN of the prod worker node IAM role."
  value       = module.eks.node_role_arn
}

output "kubeconfig_command" {
  description = "Command to add the prod cluster to your local kubeconfig."
  value       = module.eks.kubeconfig_command
}
