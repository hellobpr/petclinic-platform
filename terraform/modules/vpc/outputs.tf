# Module: vpc — outputs consumed by EKS (E-3), RDS (E-5) and DNS/Ingress (E-6).

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "IDs of the public subnets, in availability-zone order."
  value       = aws_subnet.public[*].id
}

output "subnet_cidrs" {
  description = "CIDR blocks of the public subnets, in availability-zone order."
  value       = aws_subnet.public[*].cidr_block
}

output "availability_zones" {
  description = "Availability zones the subnets occupy."
  value       = aws_subnet.public[*].availability_zone
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

# --- Security group IDs ----------------------------------------------------

output "eks_cluster_security_group_id" {
  description = "ID of the EKS control-plane security group."
  value       = aws_security_group.eks_cluster.id
}

output "eks_node_security_group_id" {
  description = "ID of the EKS worker-node security group."
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group (MySQL from nodes only)."
  value       = aws_security_group.rds.id
}

output "alb_security_group_id" {
  description = "ID of the public ALB security group."
  value       = aws_security_group.alb.id
}

output "security_group_ids" {
  description = "All security group IDs, keyed by role."
  value = {
    eks_cluster = aws_security_group.eks_cluster.id
    eks_nodes   = aws_security_group.eks_nodes.id
    rds         = aws_security_group.rds.id
    alb         = aws_security_group.alb.id
  }
}
