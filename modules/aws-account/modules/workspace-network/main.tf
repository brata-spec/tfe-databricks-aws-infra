###############################################################################
# workspace-network: ONE workspace's subnets + security group (called per team
# by the account layer). Subnets are never shared between workspaces.
#
# Looks up the client's VPC and the workspace's subnets (existing, given by
# CloudOps). Optionally creates new subnets in free CIDR space. Creates a
# dedicated security group with the Databricks rules unless one is supplied.
# Routing, NAT/egress and VPC endpoints stay owned by the client.
###############################################################################

data "aws_vpc" "this" {
  id = var.vpc_id
}

# --- Subnets ---------------------------------------------------------------------

data "aws_subnet" "existing" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

resource "aws_subnet" "new" {
  for_each          = var.new_subnets
  vpc_id            = var.vpc_id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${var.name}-${each.key}", Tier = "databricks-private" }
}

resource "aws_route_table_association" "new" {
  for_each       = var.new_subnets
  subnet_id      = aws_subnet.new[each.key].id
  route_table_id = var.route_table_ids[each.key]
}

locals {
  subnet_ids = concat(var.subnet_ids, [for s in aws_subnet.new : s.id])
  subnet_azs = distinct(concat(
    [for s in data.aws_subnet.existing : s.availability_zone],
    keys(var.new_subnets),
  ))
  wrong_vpc = [for s in data.aws_subnet.existing : s.id if s.vpc_id != var.vpc_id]

  egress_ports = {
    "https"          = [443, 443]   # control plane, S3, STS, Kinesis
    "hive-metastore" = [3306, 3306] # legacy Hive metastore
    "lakebase"       = [5432, 5432] # classic compute -> Lakebase
    "control-plane"  = [8443, 8451] # 8443/8445 API, 8444 UC lineage, 8446-8451 reserved
  }
}

resource "terraform_data" "checks" {
  input = local.subnet_ids

  lifecycle {
    precondition {
      condition     = length(local.subnet_azs) >= 2
      error_message = "${var.name}: Databricks needs subnets in at least 2 availability zones (got ${join(", ", local.subnet_azs)})."
    }
    precondition {
      condition     = length(local.wrong_vpc) == 0
      error_message = "${var.name}: subnets not in ${var.vpc_id}: ${join(", ", local.wrong_vpc)}."
    }
    precondition {
      condition     = alltrue([for az in keys(var.new_subnets) : contains(keys(var.route_table_ids), az)])
      error_message = "${var.name}: every entry in new_subnets needs a route_table_ids entry for the same AZ."
    }
  }
}

# --- Security group (dedicated per workspace) ------------------------------------------

resource "aws_security_group" "workspace" {
  count                  = var.security_group_id == null ? 1 : 0
  name                   = "${var.name}-workspace"
  description            = "Databricks workspace compute (${var.name})"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  tags                   = { Name = "${var.name}-workspace" }
}

locals {
  security_group_id = var.security_group_id != null ? var.security_group_id : aws_security_group.workspace[0].id
  create_sg_rules   = var.security_group_id == null
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  for_each                     = local.create_sg_rules ? toset(["tcp", "udp"]) : toset([])
  security_group_id            = local.security_group_id
  referenced_security_group_id = local.security_group_id
  ip_protocol                  = each.key
  from_port                    = 0
  to_port                      = 65535
  description                  = "Intra-cluster ${each.key}"
}

resource "aws_vpc_security_group_egress_rule" "self" {
  for_each                     = local.create_sg_rules ? toset(["tcp", "udp"]) : toset([])
  security_group_id            = local.security_group_id
  referenced_security_group_id = local.security_group_id
  ip_protocol                  = each.key
  from_port                    = 0
  to_port                      = 65535
  description                  = "Intra-cluster ${each.key}"
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  for_each          = local.create_sg_rules ? local.egress_ports : {}
  security_group_id = local.security_group_id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value[0]
  to_port           = each.value[1]
  description       = "Databricks ${each.key}"
}

# --- Existing VPC interface endpoints (STS, Kinesis, ...) --------------------------------
# Endpoints in a shared VPC usually only accept their own SG. Let this workspace's SG in on 443.
resource "aws_vpc_security_group_ingress_rule" "to_endpoints" {
  for_each                     = toset(var.endpoint_security_group_ids)
  security_group_id            = each.value
  referenced_security_group_id = local.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from Databricks workspace ${var.name}"
}
