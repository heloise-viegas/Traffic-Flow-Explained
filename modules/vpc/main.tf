# ═══════════════════════════════════════════════════════════
#  modules/vpc/main.tf
#
#  Creates the full network foundation:
#  VPC → Subnets → IGW → NAT Gateway → Route Tables
#
#  Public subnets  → route to IGW   (ALB lives here)
#  Private subnets → route to NAT   (EC2 lives here)
#
#  Subnets use for_each over a map(string):
#    key   = Availability Zone  (e.g. "us-east-2a")
#    value = CIDR block         (e.g. "10.0.1.0/24")
# ═══════════════════════════════════════════════════════════

# ── VPC ──────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # required for Route53 resolution inside VPC
  enable_dns_hostnames = true   # gives EC2 instances DNS names

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ── Public Subnets (one per AZ for ALB) ──────────────────
# for_each iterates the map — each.key = AZ, each.value = CIDR
resource "aws_subnet" "public" {
  for_each = var.public_subnet_cidrs

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true   # instances here get a public IP automatically

  tags = {
    Name = "${var.project_name}-public-subnet-${each.key}"
  }
}

# ── Private Subnets ───────────────────────────────────────
resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${var.project_name}-private-subnet-${each.key}"
  }
}

# ── Internet Gateway ──────────────────────────────────────
# Attached to the VPC — allows public subnets to reach the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ── Elastic IP for NAT Gateway ────────────────────────────
# NAT Gateway needs a fixed public IP
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# ── NAT Gateway ───────────────────────────────────────────
# Sits in a public subnet.
# Private subnet traffic goes through here to reach the internet
# (needed so EC2 can pull the Docker/nginx image on first boot).
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id   # place in first public subnet

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# ── Public Route Table ────────────────────────────────────
# Any traffic leaving a public subnet goes to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate every public subnet with the public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Table ───────────────────────────────────
# Traffic leaving a private subnet goes to the NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate every private subnet with the private route table
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
