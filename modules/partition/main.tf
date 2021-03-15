locals {
  common_tags = {
    Workload = var.workload
  }
  pub_subnet_tags = {
    Name = "${var.workload}-${var.partition_name}-PublicSubnet"
  }
  nat_subnet_tags = {
    Name = "${var.workload}-${var.partition_name}-PrivateSubnet"
  }
  nat_gw_eip_tags = {
    Name = "${var.workload}-${var.partition_name}-NAT"
  }
  nat_gw_tags = {
    Name = "${var.workload}-${var.partition_name}-NAT"
  }
  public_route_table_tags = {
    Name = "${var.workload}-${var.partition_name}-Public"
  }
  private_route_table_tags = {
    Name = "${var.workload}-${var.partition_name}-Private"
  }
  pub_subnet_acl_tags = {
    Name = "${var.workload}-${var.partition_name}-Public"
  }
  nat_subnet_acl_tags = {
    Name = "${var.workload}-${var.partition_name}-Private"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.pub_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, local.pub_subnet_tags)
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.nat_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  tags                    = merge(local.common_tags, local.nat_subnet_tags)
}

resource "aws_eip" "nat_ip" {
  vpc  = true
  tags = merge(local.common_tags, local.nat_gw_eip_tags)
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_ip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags          = merge(local.common_tags, local.nat_gw_tags)
}

resource "aws_route_table" "public_routes" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }
  tags = merge(local.common_tags, local.public_route_table_tags)
}

resource "aws_route_table" "private_routes" {
  vpc_id = var.vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = merge(local.common_tags, local.private_route_table_tags)
}

resource "aws_route_table_association" "public_subnet_routing" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_routes.id
}

resource "aws_route_table_association" "private_subnet_routing" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_routes.id
}

#==============================================================================
# ACLs
#------------------------------------------------------------------------------
# Define network ACLs to isolate the partition from the rest of the network.
# The subnets should be able to talk to each other, but they should not be able
# to send packets anywhere else inside the VPC.

resource "aws_network_acl" "public_subnet_acl" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.public_subnet.id]

  # Allow traffic from the public subnet to the private subnet.
  egress {
    rule_no    = 50
    cidr_block = var.nat_subnet_cidr
    action     = "allow"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }
  # Block any traffic to anywhere else on the VPC that has not been allowed
  # by the previous rule.
  egress {
    rule_no    = 55
    cidr_block = var.vpc_cidr
    action     = "deny"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }
  # Allow every other packet that was not filtered by the previous rules.
  egress {
    rule_no    = 100
    cidr_block = "0.0.0.0/0"
    action     = "allow"
    protocol   = -1
    from_port  =  0
    to_port    =  0
  }

  # Allow traffic from the private subnet to the public subnet.
  ingress {
    rule_no    = 50
    cidr_block = var.nat_subnet_cidr
    action     = "allow"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }
  # Block any traffic from anywhere else on the VPC that has not been allowed
  # by the previous rule.
  ingress {
    rule_no    = 55
    cidr_block = var.vpc_cidr
    action     = "deny"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }
  # Allow every other packet that was not filtered by the previous rules.
  ingress {
    rule_no    = 100
    cidr_block = "0.0.0.0/0"
    action     = "allow"
    protocol   = -1
    from_port  =  0
    to_port    =  0
  }

  tags = merge(local.common_tags, local.pub_subnet_acl_tags)
}

resource "aws_network_acl" "private_subnet_acl" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.private_subnet.id]

  # Allow traffic from the public subnet to the private subnet.
  egress {
    rule_no    = 50
    cidr_block = var.pub_subnet_cidr
    action     = "allow"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }
  # Block any traffic to anywhere else on the VPC that has not been allowed
  # by the previous rule.
  egress {
    rule_no    = 55
    cidr_block = var.vpc_cidr
    action     = "deny"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }

  # Allow traffic from the private subnet to the public subnet.
  ingress {
    rule_no    = 50
    cidr_block = var.pub_subnet_cidr
    action     = "allow"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }
  # Block any traffic from anywhere else on the VPC that has not been allowed
  # by the previous rule.
  ingress {
    rule_no    = 55
    cidr_block = var.vpc_cidr
    action     = "deny"
    protocol   = -1
    from_port  =  0
    to_port    =  0 
  }

  tags = merge(local.common_tags, local.nat_subnet_acl_tags)
}