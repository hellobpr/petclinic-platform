# Module: eks — IAM roles for the cluster and the worker nodes.
#
# Spec: docs/technical-spec.md#cluster-iam-role
#       docs/technical-spec.md#node-iam-role-policies
#
# Policies are AWS-managed rather than inline. Security rule 5 forbids wildcard
# IAM, and these managed policies are the least-privilege set AWS documents as
# required for EKS to function — hand-rolling them would be strictly worse.

# --- Cluster role ----------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.name_prefix}-eks-cluster-role"
  description        = "EKS control-plane role for ${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-eks-cluster-role"
    Component = "compute"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_eks_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Node role -------------------------------------------------------------

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.name_prefix}-eks-node-role"
  description        = "EKS worker node role for ${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-eks-node-role"
    Component = "compute"
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# --- IRSA role for the EBS CSI driver add-on -------------------------------
#
# The spec marks aws-ebs-csi-driver as the one add-on needing IRSA. It backs
# PersistentVolumes for Prometheus and Grafana in E-11.

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${local.name_prefix}-ebs-csi-driver-role"
  description        = "IRSA role for the aws-ebs-csi-driver add-on on ${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-ebs-csi-driver-role"
    Component = "compute"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
