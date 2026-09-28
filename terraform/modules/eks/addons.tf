# Module: eks — EKS managed add-ons.
#
# Spec: docs/technical-spec.md#eks-managed-add-ons
#
# Versions are pinned, never "latest", per spec. Refresh them with:
#   aws eks describe-addon-versions --addon-name <name> \
#     --kubernetes-version <ver> --region eu-central-1 \
#     --query 'addons[0].addonVersions[?compatibilities[0].defaultVersion==`true`].addonVersion | [0]'
#
# coredns and kube-proxy must land after the node group: both schedule pods, and
# with no nodes available the add-on create call times out as DEGRADED.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = var.addon_versions.vpc_cni

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.tags, { Component = "compute" })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = var.addon_versions.kube_proxy

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.tags, { Component = "compute" })

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = var.addon_versions.coredns

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.tags, { Component = "compute" })

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = var.addon_versions.aws_ebs_csi_driver

  # The only add-on needing IRSA — it calls the EC2 API to manage EBS volumes.
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.tags, { Component = "compute" })

  depends_on = [aws_eks_node_group.main]
}
