data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.zones[count.index]
  cidr_block              = "10.42.${count.index}.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name                     = "${var.name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "app" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.zones[count.index]
  cidr_block              = "10.42.${10 + 2 * count.index}.0/23"
  map_public_ip_on_launch = false
  tags = {
    Name                              = "${var.name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "database" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.zones[count.index]
  cidr_block              = "10.42.${20 + count.index}.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name}-db-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One NAT reduces fixed hourly cost for a short demo. It is a single-AZ dependency.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "${var.name}-nat" }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-private" }
}

resource "aws_route" "app_nat" {
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

# RDS subnets have only the VPC's local route, never an internet default route.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-isolated-db" }
}

resource "aws_route_table_association" "database" {
  count          = 2
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

resource "aws_security_group" "alb" {
  name_prefix            = "${var.name}-alb-"
  description            = "Public HTTP demo listener; use ACM and HTTPS when a domain is available"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Temporary public contact form demo"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_pods" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.nodes.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  description                  = "Only Flask IP targets"
}

resource "aws_security_group" "nodes" {
  name_prefix            = "${var.name}-nodes-"
  description            = "Private EKS worker nodes and default VPC CNI pod ENIs"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true
}

resource "aws_vpc_security_group_ingress_rule" "pods_from_alb" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  description                  = "ALB to Flask pod IP target"
}

resource "aws_vpc_security_group_egress_rule" "nodes_outbound" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "EKS, image pulls and AWS APIs through NAT"
}

resource "aws_security_group" "database" {
  name_prefix            = "${var.name}-db-"
  description            = "RDS PostgreSQL reachable from EKS worker network only"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true
}

resource "aws_vpc_security_group_ingress_rule" "db_from_nodes" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.nodes.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Flask and database bootstrap pods"
}

resource "aws_db_subnet_group" "database" {
  name       = "${var.name}-db"
  subnet_ids = aws_subnet.database[*].id
}
