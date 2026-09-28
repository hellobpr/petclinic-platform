# Module: eks — managed node group (PETPLAT-13).
#
# Spec: docs/technical-spec.md#managed-node-group
#
# t4g.small is ARM64/Graviton and covered by the AWS Graviton free trial
# (750 hrs/month until Dec 2026), which is why dev and prod use identical
# sizing. A real production cluster would use larger instances.

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = var.node_capacity_type
  ami_type       = var.node_ami_type

  # disk_size lives in the launch template's block_device_mappings instead —
  # setting it here as well is rejected when a launch template is attached.
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = merge(
    {
      "environment" = var.environment
      "managed-by"  = "terraform"
    },
    var.node_labels,
  )

  dynamic "taint" {
    for_each = var.node_taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-nodes"
    Component = "compute"
  })

  # The node group registers with the cluster using these permissions; creating
  # it before they exist fails with an opaque authorization error.
  depends_on = [
    aws_iam_role_policy_attachment.node_policies,
  ]

  lifecycle {
    # desired_size drifts once the Cluster Autoscaler or Karpenter (E-14) starts
    # scaling the group. Terraform should not fight it back to the configured
    # value on every apply.
    ignore_changes = [scaling_config[0].desired_size]
  }
}
