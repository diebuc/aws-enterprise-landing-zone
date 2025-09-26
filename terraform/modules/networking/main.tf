# Networking Module for AWS Enterprise Landing Zone
# Implements hub-and-spoke architecture with Transit Gateway

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local values for networking configuration
locals {
  # Availability zones - use first 3 AZs in the region
  availability_zones = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
  
  # Calculate subnet CIDRs dynamically
  vpc_cidr_newbits = 8  # /16 -> /24 subnets
  subnet_count = length(local.availability_zones)
  
  # Public subnets: first range
  public_subnets = [
    for i in range(local.subnet_count) :
    cidrsubnet(var.vpc_cidr, local.vpc_cidr_newbits, i)
  ]
  
  # Private subnets: second range  
  private_subnets = [
    for i in range(local.subnet_count) :
    cidrsubnet(var.vpc_cidr, local.vpc_cidr_newbits, i + local.subnet_count)
  ]
  
  # Database subnets: third range
  database_subnets = [
    for i in range(local.subnet_count) :
    cidrsubnet(var.vpc_cidr, local.vpc_cidr_newbits, i + (local.subnet_count * 2))
  ]
  
  # Transit Gateway subnets: fourth range  
  tgw_subnets = [
    for i in range(local.subnet_count) :
    cidrsubnet(var.vpc_cidr, local.vpc_cidr_newbits, i + (local.subnet_count * 3))
  ]

  # Common tags
  common_tags = merge(var.tags, {
    Module      = "networking"
    VPC         = var.vpc_name
    Environment = var.environment
  })
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # Enable VPC Flow Logs
  tags = merge(local.common_tags, {
    Name = var.vpc_name
    Type = "vpc"
  })
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "main" {
  count  = var.enable_internet_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-igw"
    Type = "internet-gateway"
  })
}

#------------------------------------------------------------------------------
# Public Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count                   = var.enable_public_subnets ? length(local.public_subnets) : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-public-${local.availability_zones[count.index]}"
    Type = "public-subnet"
    Tier = "public"
    AZ   = local.availability_zones[count.index]
  })
}

# Route table for public subnets
resource "aws_route_table" "public" {
  count  = var.enable_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id

  # Route to Internet Gateway
  dynamic "route" {
    for_each = var.enable_internet_gateway ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.main[0].id
    }
  }

  # Route to Transit Gateway for cross-VPC communication
  dynamic "route" {
    for_each = var.transit_gateway_id != null ? [1] : []
    content {
      cidr_block         = "10.0.0.0/8"  # Corporate network range
      transit_gateway_id = var.transit_gateway_id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-public-rt"
    Type = "route-table"
    Tier = "public"
  })
}

# Associate public subnets with route table
resource "aws_route_table_association" "public" {
  count          = var.enable_public_subnets ? length(aws_subnet.public) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

#------------------------------------------------------------------------------
# NAT Gateways for private subnet internet access
#------------------------------------------------------------------------------

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.availability_zones)) : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
    Type = "nat-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.availability_zones)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-nat-gw-${count.index + 1}"
    Type = "nat-gateway"
    AZ   = local.availability_zones[var.single_nat_gateway ? 0 : count.index]
  })

  depends_on = [aws_internet_gateway.main]
}

#------------------------------------------------------------------------------
# Private Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = length(local.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-private-${local.availability_zones[count.index]}"
    Type = "private-subnet"
    Tier = "private"
    AZ   = local.availability_zones[count.index]
  })
}

# Route tables for private subnets (one per AZ for NAT Gateway redundancy)
resource "aws_route_table" "private" {
  count  = length(local.private_subnets)
  vpc_id = aws_vpc.main.id

  # Route to NAT Gateway for internet access
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  # Route to Transit Gateway for cross-VPC communication  
  dynamic "route" {
    for_each = var.transit_gateway_id != null ? [1] : []
    content {
      cidr_block         = "10.0.0.0/8"  # Corporate network range
      transit_gateway_id = var.transit_gateway_id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-private-rt-${local.availability_zones[count.index]}"
    Type = "route-table"
    Tier = "private"
    AZ   = local.availability_zones[count.index]
  })
}

# Associate private subnets with route tables
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#------------------------------------------------------------------------------
# Database Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "database" {
  count             = var.enable_database_subnets ? length(local.database_subnets) : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnets[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-db-${local.availability_zones[count.index]}"
    Type = "database-subnet"
    Tier = "database"
    AZ   = local.availability_zones[count.index]
  })
}

# Database subnet group for RDS
resource "aws_db_subnet_group" "main" {
  count      = var.enable_database_subnets ? 1 : 0
  name       = "${var.vpc_name}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-db-subnet-group"
    Type = "db-subnet-group"
  })
}

# Route table for database subnets (no internet access by default)
resource "aws_route_table" "database" {
  count  = var.enable_database_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id

  # Route to Transit Gateway for cross-VPC database access
  dynamic "route" {
    for_each = var.transit_gateway_id != null ? [1] : []
    content {
      cidr_block         = "10.0.0.0/8"  # Corporate network range
      transit_gateway_id = var.transit_gateway_id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-db-rt"
    Type = "route-table"
    Tier = "database"
  })
}

# Associate database subnets with route table
resource "aws_route_table_association" "database" {
  count          = var.enable_database_subnets ? length(aws_subnet.database) : 0
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

#------------------------------------------------------------------------------
# Transit Gateway Subnets (for TGW attachments)
#------------------------------------------------------------------------------

resource "aws_subnet" "transit_gateway" {
  count             = var.enable_transit_gateway_subnets ? length(local.tgw_subnets) : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.tgw_subnets[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-tgw-${local.availability_zones[count.index]}"
    Type = "transit-gateway-subnet"
    Tier = "transit"
    AZ   = local.availability_zones[count.index]
  })
}

#------------------------------------------------------------------------------
# Security Groups
#------------------------------------------------------------------------------

# Default security group with restrictive rules
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # Remove all default rules and add restrictive ones
  ingress = []
  egress  = []

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-default-sg-restrictive"
    Type = "security-group"
  })
}

# Web tier security group
resource "aws_security_group" "web_tier" {
  count       = var.create_security_groups ? 1 : 0
  name_prefix = "${var.vpc_name}-web-"
  description = "Security group for web tier (ALB, web servers)"
  vpc_id      = aws_vpc.main.id

  # HTTP from anywhere
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-web-tier-sg"
    Type = "security-group"
    Tier = "web"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application tier security group
resource "aws_security_group" "app_tier" {
  count       = var.create_security_groups ? 1 : 0
  name_prefix = "${var.vpc_name}-app-"
  description = "Security group for application tier"
  vpc_id      = aws_vpc.main.id

  # Application port from web tier
  ingress {
    description     = "App port from web tier"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier[0].id]
  }

  # SSH from bastion (if enabled)
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      description = "SSH from VPC"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-app-tier-sg"
    Type = "security-group"
    Tier = "application"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Database tier security group
resource "aws_security_group" "db_tier" {
  count       = var.create_security_groups && var.enable_database_subnets ? 1 : 0
  name_prefix = "${var.vpc_name}-db-"
  description = "Security group for database tier"
  vpc_id      = aws_vpc.main.id

  # MySQL/Aurora from application tier
  ingress {
    description     = "MySQL/Aurora from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier[0].id]
  }

  # PostgreSQL from application tier
  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier[0].id]
  }

  # No outbound internet access for security
  egress {
    description = "Database replication traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-db-tier-sg"
    Type = "security-group"
    Tier = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#------------------------------------------------------------------------------
# VPC Flow Logs
#------------------------------------------------------------------------------

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.vpc_name}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.vpc_name}-flow-log-policy"
  role  = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.vpc_name}"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-flow-logs"
    Type = "cloudwatch-log-group"
  })
}

# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  count           = var.enable_flow_logs ? 1 : 0
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type    = var.flow_logs_traffic_type
  vpc_id          = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-flow-log"
    Type = "vpc-flow-log"
  })
}

#------------------------------------------------------------------------------
# Transit Gateway Attachment
#------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  count                                           = var.transit_gateway_id != null ? 1 : 0
  subnet_ids                                      = var.enable_transit_gateway_subnets ? aws_subnet.transit_gateway[*].id : aws_subnet.private[*].id
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.main.id
  appliance_mode_support                          = var.transit_gateway_appliance_mode_support
  dns_support                                     = var.transit_gateway_dns_support
  ipv6_support                                    = var.transit_gateway_ipv6_support
  transit_gateway_default_route_table_association = var.transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation = var.transit_gateway_default_route_table_propagation

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-tgw-attachment"
    Type = "transit-gateway-attachment"
  })
}

#------------------------------------------------------------------------------
# Network ACLs (Optional additional security layer)
#------------------------------------------------------------------------------

# Public subnet NACL
resource "aws_network_acl" "public" {
  count  = var.enable_network_acls && var.enable_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow inbound HTTP
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow inbound HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-public-nacl"
    Type = "network-acl"
    Tier = "public"
  })
}

# Private subnet NACL
resource "aws_network_acl" "private" {
  count  = var.enable_network_acls ? 1 : 0
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Allow inbound from VPC
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow return traffic from internet
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-private-nacl"
    Type = "network-acl"
    Tier = "private"
  })
}
