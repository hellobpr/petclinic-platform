# Module: eks — outputs consumed by K8s manifests (E-8), secrets/IRSA (E-7),
# observability (E-11) and Karpenter (E-14).

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster."
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group attached to the control plane."
  value       = var.cluster_security_group_id
}

output "cluster_managed_security_group_id" {
  description = "Security group EKS creates and manages for the cluster. Distinct from the one passed in; EKS uses it for control-plane-to-node traffic."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# --- OIDC / IRSA -----------------------------------------------------------

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider. Use as the Federated principal in IRSA trust policies."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without the https:// scheme, as IAM condition keys expect."
  value       = local.oidc_provider_url
}

output "oidc_issuer_url" {
  description = "Full OIDC issuer URL including scheme."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# --- Node group ------------------------------------------------------------

output "node_group_name" {
  description = "Name of the managed node group."
  value       = aws_eks_node_group.main.node_group_name
}

output "node_role_arn" {
  description = "ARN of the worker node IAM role."
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the worker node IAM role. Needed when attaching extra policies in later epics."
  value       = aws_iam_role.node.name
}

output "launch_template_id" {
  description = "ID of the node launch template."
  value       = aws_launch_template.nodes.id
}

# --- Access ----------------------------------------------------------------

output "kubeconfig_command" {
  description = "Command to add this cluster to your local kubeconfig."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${data.aws_region.current.name}"
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IRSA role used by the aws-ebs-csi-driver add-on."
  value       = aws_iam_role.ebs_csi_driver.arn
}
