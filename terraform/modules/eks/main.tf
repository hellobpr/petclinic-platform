# Module: eks — cluster and OIDC provider (PETPLAT-12).
#
# Spec: docs/technical-spec.md#eks-cluster
#
# Cluster and nodes both live in the public subnets from the vpc module. There
# are no private subnets in this design; the security groups passed in from the
# vpc module are the perimeter. See ADR-0001.

data "aws_region" "current" {}

locals {
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = local.name_prefix

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  # The identity issuer URL without its scheme, which is the form IAM condition
  # keys expect ("oidc.eks.<region>.amazonaws.com/id/<id>:sub").
  oidc_provider_url = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

# --- Cluster ---------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.cluster_security_group_id]

    # Public endpoint: there is no bastion and no private networking in this
    # design, so kubectl and the AWS Load Balancer Controller reach the API
    # server over the internet. Restrict with var.public_access_cidrs.
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  # API_AND_CONFIG_MAP keeps the legacy aws-auth ConfigMap working while
  # allowing the newer access-entry API used in access.tf (PETPLAT-14).
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = merge(local.tags, {
    Name      = local.cluster_name
    Component = "compute"
  })

  # Without this the cluster can be created before its role has the policy
  # attached, which EKS rejects.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_eks_policy,
  ]
}

# --- OIDC provider for IRSA ------------------------------------------------

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-eks-oidc"
    Component = "compute"
  })
}
