data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

# ─── VPC ────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc-${var.environment_name}" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-igw-${var.environment_name}" }
}

# ─── Public subnets (ALB) ───────────────────────────────────────────────────────

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.az_a
  cidr_block              = var.public_subnet_a_cidr
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-a-${var.environment_name}" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.az_b
  cidr_block              = var.public_subnet_b_cidr
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-b-${var.environment_name}" }
}

# ─── Service subnets (ECS Fargate) ──────────────────────────────────────────────

resource "aws_subnet" "service_a" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.az_a
  cidr_block              = var.service_subnet_a_cidr
  map_public_ip_on_launch = false

  tags = { Name = "${var.project_name}-svc-a-${var.environment_name}" }
}

resource "aws_subnet" "service_b" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.az_b
  cidr_block              = var.service_subnet_b_cidr
  map_public_ip_on_launch = false

  tags = { Name = "${var.project_name}-svc-b-${var.environment_name}" }
}

# ─── Route tables ───────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-public-rt-${var.environment_name}" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "service_a" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-svc-rt-a-${var.environment_name}" }
}

resource "aws_route_table" "service_b" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-svc-rt-b-${var.environment_name}" }
}

resource "aws_route_table_association" "service_a" {
  subnet_id      = aws_subnet.service_a.id
  route_table_id = aws_route_table.service_a.id
}

resource "aws_route_table_association" "service_b" {
  subnet_id      = aws_subnet.service_b.id
  route_table_id = aws_route_table.service_b.id
}

# ─── VPC Endpoints (replace NAT Gateways for private subnet AWS access) ────────

resource "aws_security_group" "vpce" {
  name_prefix = "${var.project_name}-vpce-"
  description = "${var.project_name} VPC endpoint SG - allows HTTPS from within VPC"
  vpc_id      = aws_vpc.this.id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project_name}-vpce-sg-${var.environment_name}" }

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.service_a.id,
    aws_route_table.service_b.id,
  ]
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.service_a.id, aws_subnet.service_b.id]
  security_group_ids  = [aws_security_group.vpce.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.service_a.id, aws_subnet.service_b.id]
  security_group_ids  = [aws_security_group.vpce.id]
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.service_a.id, aws_subnet.service_b.id]
  security_group_ids  = [aws_security_group.vpce.id]
}
