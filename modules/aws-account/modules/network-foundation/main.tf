###############################################################################
# network-foundation: the environment's VPC (once per AWS account/environment)
#
#   mode = "existing": look up a VPC + its private route tables (CloudOps owns
#                      NAT, endpoints, routing). Nothing is created.
#   mode = "create":   VPC, IGW, one public subnet + NAT, one private route
#                      table per AZ, S3 gateway endpoint, optional STS/Kinesis
#                      interface endpoints.
#
# Workspace subnets are NOT created here; each workspace gets its own subnets
# and security group in ../workspace-network (attached to the private
# route tables output below).
###############################################################################

locals {
  create = var.mode == "create"
}

# ------------------------------------------------------------------ existing
data "aws_vpc" "existing" {
  count = local.create ? 0 : 1
  id    = var.existing.vpc_id
}

data "aws_route_table" "existing" {
  for_each       = local.create ? {} : var.existing.private_route_table_ids
  route_table_id = each.value
}

# ------------------------------------------------------------------ create
resource "aws_vpc" "this" {
  count                = local.create ? 1 : 0
  cidr_block           = var.create.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  count  = local.create ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = merge(var.tags, { Name = var.name })
}

resource "aws_subnet" "public" {
  count             = local.create ? 1 : 0
  vpc_id            = aws_vpc.this[0].id
  cidr_block        = var.create.public_subnet_cidr
  availability_zone = var.create.azs[0]
  tags              = merge(var.tags, { Name = "${var.name}-public-${var.create.azs[0]}" })
}

resource "aws_route_table" "public" {
  count  = local.create ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route_table_association" "public" {
  count          = local.create ? 1 : 0
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count  = local.create ? 1 : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat" })
}

resource "aws_nat_gateway" "this" {
  count         = local.create ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = var.name })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  for_each = local.create ? toset(var.create.azs) : toset([])
  vpc_id   = aws_vpc.this[0].id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }
  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_vpc_endpoint" "s3" {
  count             = local.create ? 1 : 0
  vpc_id            = aws_vpc.this[0].id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]
  tags              = merge(var.tags, { Name = "${var.name}-s3" })
}

# Optional interface endpoints (STS, Kinesis). Traffic otherwise goes via NAT.
locals {
  interface_endpoints = local.create && var.create.interface_endpoints ? toset(["sts", "kinesis-streams"]) : toset([])
}

resource "aws_subnet" "endpoints" {
  for_each          = length(local.interface_endpoints) > 0 ? var.create.endpoint_subnet_cidrs : {}
  vpc_id            = aws_vpc.this[0].id
  cidr_block        = each.value
  availability_zone = each.key
  tags              = merge(var.tags, { Name = "${var.name}-endpoints-${each.key}" })
}

resource "aws_security_group" "endpoints" {
  count       = length(local.interface_endpoints) > 0 ? 1 : 0
  name        = "${var.name}-endpoints"
  description = "VPC interface endpoints: HTTPS from inside the VPC"
  vpc_id      = aws_vpc.this[0].id
  tags        = merge(var.tags, { Name = "${var.name}-endpoints" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count             = length(local.interface_endpoints) > 0 ? 1 : 0
  security_group_id = aws_security_group.endpoints[0].id
  cidr_ipv4         = var.create.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS from the VPC"
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoints
  vpc_id              = aws_vpc.this[0].id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.endpoints : s.id]
  security_group_ids  = [aws_security_group.endpoints[0].id]
  tags                = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# ------------------------------------------------------------------ checks
resource "terraform_data" "checks" {
  input = var.mode
  lifecycle {
    precondition {
      condition     = local.create || (var.existing.vpc_id != null && length(var.existing.private_route_table_ids) >= 2)
      error_message = "mode = \"existing\" needs existing.vpc_id and private_route_table_ids for at least 2 AZs."
    }
    precondition {
      condition     = !local.create || (var.create.vpc_cidr != null && length(var.create.azs) >= 2 && var.create.public_subnet_cidr != null)
      error_message = "mode = \"create\" needs create.vpc_cidr, create.public_subnet_cidr and at least 2 create.azs."
    }
    precondition {
      condition     = local.create || alltrue([for rt in data.aws_route_table.existing : rt.vpc_id == var.existing.vpc_id])
      error_message = "Every existing.private_route_table_ids entry must belong to existing.vpc_id."
    }
  }
}
