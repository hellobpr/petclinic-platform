# Module: vpc — VPC, public subnets, Internet Gateway, routing (PETPLAT-6).
#
# All-public subnet design: no NAT Gateway, no private subnets, no VPC
# endpoints. Every resource (EKS nodes, RDS, ALB) sits in a public subnet and
# security groups are the access-control perimeter. This trades the usual
# private-subnet isolation for ~$35-65/month saved on NAT. See ADR-0001.
#
# Spec: docs/technical-spec.md#vpc-network-design

locals {
  name_prefix = "${var.project}-${var.environment}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  # EKS discovers subnets by tag. "shared" lets more than one cluster use them;
  # kubernetes.io/role/elb marks them as valid targets for public load balancers.
  # Spec: docs/technical-spec.md#eks-subnet-tags-required
  eks_subnet_tags = {
    "kubernetes.io/cluster/${local.name_prefix}" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  }
}

# --- VPC -------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-vpc"
    Component = "networking"
  })
}

# --- Internet Gateway ------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-igw"
    Component = "networking"
  })
}

# --- Public subnets --------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Required: nodes and the ALB need public IPs, as there is no NAT path out.
  map_public_ip_on_launch = true

  tags = merge(local.tags, local.eks_subnet_tags, {
    Name      = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Component = "networking"
    Tier      = "public"
  })

  lifecycle {
    # The two lists are zipped by index. Without this, a length mismatch
    # surfaces as an opaque "index out of range" during plan.
    precondition {
      condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
      error_message = "public_subnet_cidrs and availability_zones must be the same length; they are paired by index."
    }
  }
}

# --- Routing ---------------------------------------------------------------

# One route table shared by both subnets. There are no private subnets, so a
# single 0.0.0.0/0 -> IGW route serves the whole VPC.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name      = "${local.name_prefix}-public-rt"
    Component = "networking"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NOTE: No aws_nat_gateway and no aws_eip here, deliberately. Adding a NAT
# Gateway would cost ~$35/month plus data processing and is not needed when
# every subnet routes directly to the IGW. See ADR-0001.
