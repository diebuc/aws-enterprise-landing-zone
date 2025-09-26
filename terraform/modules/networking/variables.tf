# Variables for Networking Module

#------------------------------------------------------------------------------
# Basic VPC Configuration
#------------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

#------------------------------------------------------------------------------
# DNS Configuration
#------------------------------------------------------------------------------

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Internet Gateway & Public Subnets
#------------------------------------------------------------------------------

variable "enable_internet_gateway" {
  description = "Enable Internet Gateway for the VPC"
  type        = bool
  default     = true
}

variable "enable_public_subnets" {
  description = "Enable creation of public subnets"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# NAT Gateway Configuration
#------------------------------------------------------------------------------

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Database Subnets
#------------------------------------------------------------------------------

variable "enable_database_subnets" {
  description = "Enable creation of database subnets"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Transit Gateway Configuration
#------------------------------------------------------------------------------

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway to attach to"
  type        = string
  default     = null
}

variable "enable_transit_gateway_subnets" {
  description = "Create dedicated subnets for Transit Gateway attachments"
  type        = bool
  default     = false
}

variable "transit_gateway_appliance_mode_support" {
  description = "Enable appliance mode support for Transit Gateway attachment"
  type        = string
  default     = "disable"
  validation {
    condition     = contains(["enable", "disable"], var.transit_gateway_appliance_mode_support)
    error_message = "Transit Gateway appliance mode support must be 'enable' or 'disable'."
  }
}

variable "transit_gateway_dns_support" {
  description = "Enable DNS support for Transit Gateway attachment"
  type        = string
  default     = "enable"
  validation {
    condition     = contains(["enable", "disable"], var.transit_gateway_dns_support)
    error_message = "Transit Gateway DNS support must be 'enable' or 'disable'."
  }
}

variable "transit_gateway_ipv6_support" {
  description = "Enable IPv6 support for Transit Gateway attachment"
  type        = string
  default     = "disable"
  validation {
    condition     = contains(["enable", "disable"], var.transit_gateway_ipv6_support)
    error_message = "Transit Gateway IPv6 support must be 'enable' or 'disable'."
  }
}

variable "transit_gateway_default_route_table_association" {
  description = "Enable default route table association for Transit Gateway attachment"
  type        = string
  default     = "enable"
  validation {
    condition     = contains(["enable", "disable"], var.transit_gateway_default_route_table_association)
    error_message = "Transit Gateway default route table association must be 'enable' or 'disable'."
  }
}

variable "transit_gateway_default_route_table_propagation" {
  description = "Enable default route table propagation for Transit Gateway attachment"
  type        = string
  default     = "enable"
  validation {
    condition     = contains(["enable", "disable"], var.transit_gateway_default_route_table_propagation)
    error_message = "Transit Gateway default route table propagation must be 'enable' or 'disable'."
  }
}

#------------------------------------------------------------------------------
# Security Groups
#------------------------------------------------------------------------------

variable "create_security_groups" {
  description = "Create default security groups for web, app, and database tiers"
  type        = bool
  default     = true
}

variable "app_port" {
  description = "Port for application tier communication"
  type        = number
  default     = 8080
}

variable "enable_ssh_access" {
  description = "Enable SSH access to application tier from within VPC"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# VPC Flow Logs
#------------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to capture in flow logs (ALL, ACCEPT, REJECT)"
  type        = string
  default     = "ALL"
  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "Flow logs traffic type must be ALL, ACCEPT, or REJECT."
  }
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs"
  type        = number
  default     = 30
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.flow_logs_retention_days)
    error_message = "Flow logs retention must be a valid CloudWatch Logs retention value."
  }
}

#------------------------------------------------------------------------------
# Network ACLs
#------------------------------------------------------------------------------

variable "enable_network_acls" {
  description = "Enable custom Network ACLs for additional security"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
