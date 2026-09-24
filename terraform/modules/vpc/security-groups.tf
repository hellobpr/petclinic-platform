# Module: vpc — baseline security groups (PETPLAT-8).
#
# In this all-public subnet design these four groups ARE the perimeter. They
# are written to be as restrictive as a private-subnet setup would be: nothing
# reaches RDS except the nodes, and only the ALB is exposed to the internet.
#
# Spec: docs/technical-spec.md#security-groups
#
# Rules live in separate aws_vpc_security_group_*_rule resources rather than
# inline ingress/egress blocks. The cluster SG must allow the node SG and the
# node SG must allow the cluster SG; expressed inline that is a circular
# reference Terraform cannot resolve.

# --- Security group shells -------------------------------------------------

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "EKS control plane. Accepts API traffic from worker nodes only."
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-eks-cluster-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "eks_nodes" {
  name        = "${local.name_prefix}-eks-node-sg"
  description = "EKS worker nodes. Accepts control-plane, peer-node and ALB traffic."
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-eks-node-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS MySQL. Accepts 3306 from EKS nodes only, never from the internet."
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-rds-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Public ALB. Accepts 80/443 from the internet, forwards to node NodePorts."
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-alb-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# --- EKS cluster SG rules --------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "cluster_api_from_nodes" {
  security_group_id = aws_security_group.eks_cluster.id
  description       = "Kubernetes API from worker nodes"

  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.eks_nodes.id

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "cluster_all_outbound" {
  security_group_id = aws_security_group.eks_cluster.id
  description       = "All outbound"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = local.tags
}

# --- EKS node SG rules -----------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "nodes_all_from_cluster" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "All traffic from the EKS control plane"

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.eks_cluster.id

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "nodes_all_from_self" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Inter-node communication (pod-to-pod, CNI)"

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.eks_nodes.id

  tags = local.tags
}

# Subsumed by nodes_all_from_cluster above (which allows all protocols from the
# same source), but the spec lists kubelet 10250 explicitly. Kept so the intent
# survives if the broad rule is ever tightened.
resource "aws_vpc_security_group_ingress_rule" "nodes_kubelet_from_cluster" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Kubelet API from the EKS control plane"

  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  referenced_security_group_id = aws_security_group.eks_cluster.id

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "nodes_nodeport_from_alb" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "NodePort range from the ALB"

  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  referenced_security_group_id = aws_security_group.alb.id

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "nodes_all_outbound" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "All outbound (ECR, S3, Secrets Manager via IGW)"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = local.tags
}

# --- RDS SG rules ----------------------------------------------------------

# The single most important rule in this file: MySQL is reachable from the node
# security group and nothing else. The database sits in a public subnet, so this
# rule is the only thing standing between it and the internet.
resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_nodes" {
  security_group_id = aws_security_group.rds.id
  description       = "MySQL 3306 from EKS nodes only"

  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.eks_nodes.id

  tags = local.tags
}

# No egress rules for RDS. The spec defines no outbound requirement, and an
# aws_security_group with no egress rule attached permits nothing outbound --
# unlike the AWS console default of allow-all.

# --- ALB SG rules ----------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_from_internet" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "alb_nodeport_to_nodes" {
  security_group_id = aws_security_group.alb.id
  description       = "NodePort range to EKS nodes"

  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  referenced_security_group_id = aws_security_group.eks_nodes.id

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "alb_health_to_nodes" {
  security_group_id = aws_security_group.alb.id
  description       = "Health checks to EKS nodes on 8080"

  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.eks_nodes.id

  tags = local.tags
}
