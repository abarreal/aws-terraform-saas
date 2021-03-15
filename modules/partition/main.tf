locals {
  common_tags = {
    Workload = var.workload
  }
  public_subnet_tags = {
    Name = "${var.workload}-${var.partition_name}-PublicSubnet"
  }
  private_subnet_tags = {
    Name = "${var.workload}-${var.partition_name}-PrivateSubnet"
  }
  public_route_table_tags = {
    Name = "${var.workload}-${var.partition_name}-Public"
  }
  private_route_table_tags = {
    Name = "${var.workload}-${var.partition_name}-Private"
  }
  public_subnet_acl_tags = {
    Name = "${var.workload}-${var.partition_name}-Public"
  }
  private_subnet_acl_tags = {
    Name = "${var.workload}-${var.partition_name}-Private"
  }
  private_resource_sg_tags = {
    Name = "${var.workload}-${var.partition_name}-PrivateResource"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, local.public_subnet_tags)
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  tags                    = merge(local.common_tags, local.private_subnet_tags)
  # This scheme does not use a NAT gateway, so public IP addresses are
  # required (they need not to be static, however).
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public_routes" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }
  tags = merge(local.common_tags, local.public_route_table_tags)
}

# Since no NAT is being used yet, the route table for the private subnet looks
# in fact just like the one for the public subnet. Replace gateway_id for
# nat_gateway_id if migrating to a NAT based configuration.
resource "aws_route_table" "private_routes" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
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

# Define a security group which allows inbound packets only from the public 
# subnet and the security group itself. This security group should be assigned
# to all resources in the private subnet unless customization is needed. Unlike 
# the NAT alternative, this is not a secure-by-default approach. For a small 
# self-funded group without many instances in the private subnet, in which 
# everyone is aware of the details of the infrastructure, this approach is 
# acceptable as long as care is taken to assign appropriate security group 
# rules when deploying new resources. If the deployment of resources to the 
# private subnet becomes more chaotic (e.g. self-service), however, a 
# secure-by-default approach is advisable.
resource "aws_security_group" "private_resource" {
  name        = local.private_resource_sg_tags.Name
  description = "Allow access only from the public subnet and the SG itself."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound packets from the public subnet."
    cidr_blocks = [ aws_subnet.public_subnet.cidr_block ]
    protocol    = -1
    from_port   =  0
    to_port     =  0
  }

  ingress {
    description = "Allow private resources to communicate with each other."
    self        = true
    protocol    = -1
    from_port   =  0
    to_port     =  0
  }

  egress {
    description = "Allow all outbound packets."
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol    = -1
    from_port   =  0
    to_port     =  0
  }

  tags = merge(local.private_resource_sg_tags, local.common_tags)
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
    cidr_block = var.private_subnet_cidr
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
    cidr_block = var.private_subnet_cidr
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

  tags = merge(local.common_tags, local.public_subnet_acl_tags)
}

resource "aws_network_acl" "private_subnet_acl" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.private_subnet.id]

  # Allow traffic from the public subnet to the private subnet.
  egress {
    rule_no    = 50
    cidr_block = var.public_subnet_cidr
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
    cidr_block = var.public_subnet_cidr
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

  tags = merge(local.common_tags, local.private_subnet_acl_tags)
}