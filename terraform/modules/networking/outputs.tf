# Outputs for Networking Module

#------------------------------------------------------------------------------
# VPC Information
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_vpc.main.default_security_group_id
}

output "vpc_default_network_acl_id" {
  description = "ID of the default network ACL"
  value       = aws_vpc.main.default_network_acl_id
}

output "vpc_default_route_table_id" {
  description = "ID of the default route table"
  value       = aws_vpc.main.default_route_table_id
}

#------------------------------------------------------------------------------
# Internet Gateway
#------------------------------------------------------------------------------

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = try(aws_internet_gateway.main[0].id, null)
}

output "internet_gateway_arn" {
  description = "ARN of the Internet Gateway"
  value       = try(aws_internet_gateway.main[0].arn, null)
}

#------------------------------------------------------------------------------
# Availability Zones
#------------------------------------------------------------------------------

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.availability_zones
}

#------------------------------------------------------------------------------
# Public Subnets
#------------------------------------------------------------------------------

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_arns" {
  description = "List of ARNs of the public subnets"
  value       = aws_subnet.public[*].arn
}

output "public_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_availability_zones" {
  description = "List of availability zones of the public subnets"
  value       = aws_subnet.public[*].availability_zone
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = try(aws_route_table.public[0].id, null)
}

#------------------------------------------------------------------------------
# Private Subnets
#------------------------------------------------------------------------------

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_arns" {
  description = "List of ARNs of the private subnets"
  value       = aws_subnet.private[*].arn
}

output "private_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_availability_zones" {
  description = "List of availability zones of the private subnets"
  value       = aws_subnet.private[*].availability_zone
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

#------------------------------------------------------------------------------
# Database Subnets
#------------------------------------------------------------------------------

output "database_subnet_ids" {
  description = "List of IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "database_subnet_arns" {
  description = "List of ARNs of the database subnets"
  value       = aws_subnet.database[*].arn
}

output "database_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the database subnets"
  value       = aws_subnet.database[*].cidr_block
}

output "database_subnet_availability_zones" {
  description = "List of availability zones of the database subnets"
  value       = aws_subnet.database[*].availability_zone
}

output "database_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = try(aws_db_subnet_group.main[0].id, null)
}

output "database_subnet_group_arn" {
  description = "ARN of the database subnet group"
  value       = try(aws_db_subnet_group.main[0].arn, null)
}

output "database_route_table_id" {
  description = "ID of the database route table"
  value       = try(aws_route_table.database[0].id, null)
}

#------------------------------------------------------------------------------
# Transit Gateway Subnets
#------------------------------------------------------------------------------

output "transit_gateway_subnet_ids" {
  description = "List of IDs of the Transit Gateway subnets"
  value       = aws_subnet.transit_gateway[*].id
}

output "transit_gateway_subnet_arns" {
  description = "List of ARNs of the Transit Gateway subnets"
  value       = aws_subnet.transit_gateway[*].arn
}

output "transit_gateway_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the Transit Gateway subnets"
  value       = aws_subnet.transit_gateway[*].cidr_block
}

#------------------------------------------------------------------------------
# NAT Gateways
#------------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public IP addresses associated with the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "nat_gateway_allocation_ids" {
  description = "List of allocation IDs of the Elastic IPs for NAT Gateways"
  value       = aws_eip.nat[*].allocation_id
}

#------------------------------------------------------------------------------
# Security Groups
#------------------------------------------------------------------------------

output "web_tier_security_group_id" {
  description = "ID of the web tier security group"
  value       = try(aws_security_group.web_tier[0].id, null)
}

output "web_tier_security_group_arn" {
  description = "ARN of the web tier security group"
  value       = try(aws_security_group.web_tier[0].arn, null)
}

output "app_tier_security_group_id" {
  description = "ID of the application tier security group"
  value       = try(aws_security_group.app_tier[0].id, null)
}

output "app_tier_security_group_arn" {
  description = "ARN of the application tier security group"
  value       = try(aws_security_group.app_tier[0].arn, null)
}

output "database_tier_security_group_id" {
  description = "ID of the database tier security group"
  value       = try(aws_security_group.db_tier[0].id, null)
}

output "database_tier_security_group_arn" {
  description = "ARN of the database tier security group"
  value       = try(aws_security_group.db_tier[0].arn, null)
}

#------------------------------------------------------------------------------
# Transit Gateway Attachment
#------------------------------------------------------------------------------

output "transit_gateway_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment"
  value       = try(aws_ec2_transit_gateway_vpc_attachment.main[0].id, null)
}

output "transit_gateway_attachment_state" {
  description = "State of the Transit Gateway VPC attachment"
  value       = try(aws_ec2_transit_gateway_vpc_attachment.main[0].state, null)
}

#------------------------------------------------------------------------------
# VPC Flow Logs
#------------------------------------------------------------------------------

output "flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = try(aws_flow_log.vpc[0].id, null)
}

output "flow_log_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for VPC Flow Logs"
  value       = try(aws_cloudwatch_log_group.vpc_flow_log[0].arn, null)
}

#------------------------------------------------------------------------------
# Network ACLs
#------------------------------------------------------------------------------

output "public_network_acl_id" {
  description = "ID of the public network ACL"
  value       = try(aws_network_acl.public[0].id, null)
}

output "private_network_acl_id" {
  description = "ID of the private network ACL"
  value       = try(aws_network_acl.private[0].id, null)
}

#------------------------------------------------------------------------------
# Subnet Groups by Tier
#------------------------------------------------------------------------------

output "subnet_groups" {
  description = "Map of subnet groups organized by tier"
  value = {
    public = {
      subnet_ids = aws_subnet.public[*].id
      cidr_blocks = aws_subnet.public[*].cidr_block
      availability_zones = aws_subnet.public[*].availability_zone
    }
    private = {
      subnet_ids = aws_subnet.private[*].id
      cidr_blocks = aws_subnet.private[*].cidr_block
      availability_zones = aws_subnet.private[*].availability_zone
    }
    database = {
      subnet_ids = aws_subnet.database[*].id
      cidr_blocks = aws_subnet.database[*].cidr_block
      availability_zones = aws_subnet.database[*].availability_zone
    }
    transit_gateway = {
      subnet_ids = aws_subnet.transit_gateway[*].id
      cidr_blocks = aws_subnet.transit_gateway[*].cidr_block
      availability_zones = aws_subnet.transit_gateway[*].availability_zone
    }
  }
}

#------------------------------------------------------------------------------
# Summary Information
#------------------------------------------------------------------------------

output "networking_summary" {
  description = "Summary of networking resources created"
  value = {
    vpc_id = aws_vpc.main.id
    vpc_cidr = aws_vpc.main.cidr_block
    availability_zones = local.availability_zones
    public_subnets_count = length(aws_subnet.public)
    private_subnets_count = length(aws_subnet.private)
    database_subnets_count = length(aws_subnet.database)
    nat_gateways_count = length(aws_nat_gateway.main)
    internet_gateway_enabled = var.enable_internet_gateway
    flow_logs_enabled = var.enable_flow_logs
    transit_gateway_attached = var.transit_gateway_id != null
  }
}
