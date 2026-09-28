# Module: eks — launch template for the managed node group (PETPLAT-13).
#
# A launch template is required here for two reasons, not convenience:
#
#   1. Security group attachment. A bare aws_eks_node_group gives nodes the
#      cluster's own managed security group; there is no argument to attach the
#      node SG from the vpc module. Only a launch template can.
#   2. EBS encryption. Security rule 4 in CLAUDE.md requires encryption
#      everywhere, and EKS node root volumes are NOT encrypted by default.
#
# image_id is deliberately omitted. Supplying one would make this a "custom AMI"
# node group, which shifts responsibility for the kubelet bootstrap userdata onto
# us. Leaving it unset lets EKS pick the AL2023 ARM64 AMI for the cluster version
# and inject its own bootstrap.

resource "aws_launch_template" "nodes" {
  name        = "${local.name_prefix}-eks-node-lt"
  description = "Launch template for ${local.cluster_name} worker nodes"

  vpc_security_group_ids = [
    var.node_security_group_id,
    var.cluster_security_group_id,
  ]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # IMDSv2 required. IMDSv1 lets any process that can make an HTTP request reach
  # the instance credentials, which is the classic SSRF-to-node-role path.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  # Tags for the EC2 instances and volumes the node group creates. Resource tags
  # on the node group itself do not propagate to instances.
  tag_specifications {
    resource_type = "instance"

    tags = merge(local.tags, {
      Name      = "${local.name_prefix}-node"
      Component = "compute"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(local.tags, {
      Name      = "${local.name_prefix}-node-volume"
      Component = "compute"
    })
  }

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-eks-node-lt"
    Component = "compute"
  })

  lifecycle {
    create_before_destroy = true
  }
}
