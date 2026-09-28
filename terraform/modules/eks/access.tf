# Module: eks — cluster access for IAM principals (PETPLAT-14).
#
# Spec: docs/technical-spec.md#eks-cluster
#
# Uses the access-entry API rather than hand-editing the aws-auth ConfigMap.
# Access entries are real AWS resources, so they are visible in state and in
# the console, and a mistake is revertible — whereas a botched aws-auth edit can
# lock everyone out of the cluster with no way back in.
#
# The principal running `terraform apply` already gets admin via
# bootstrap_cluster_creator_admin_permissions (see main.tf). The entries below
# are for ADDITIONAL users and roles.
#
# To add someone, append to var.cluster_admin_principals in the environment:
#
#   cluster_admin_principals = [
#     "arn:aws:iam::372315927833:user/alice",
#     "arn:aws:iam::372315927833:role/PlatformEngineer",
#   ]
#
# They then run the command from the kubeconfig_command output. To grant less
# than full admin, swap the policy ARN for AmazonEKSViewPolicy or
# AmazonEKSEditPolicy, or scope it to a namespace with an access_scope of type
# "namespace". See:
#   https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html

resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.cluster_admin_principals)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = merge(local.tags, { Component = "compute" })
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.cluster_admin_principals)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}
