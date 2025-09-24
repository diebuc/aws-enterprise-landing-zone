# Variables for AWS Enterprise Landing Zone

# Basic Configuration
variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "management"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "enterprise-landing-zone"
}

# Organization Configuration
variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "Enterprise Organization"
}

variable "organization_domain" {
  description = "Domain for organization email addresses"
  type        = string
  default     = "company.com"
}

# Tagging and Governance
variable "cost_center" {
  description = "Cost center for resource allocation"
  type        = string
  default     = "infrastructure"
}

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
  default     = "cloud-team@company.com"
}

variable "compliance_frameworks" {
  description = "List of compliance frameworks to adhere to"
  type        = list(string)
  default     = ["sox", "pci-dss", "gdpr"]
}

# Security Features
variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail organization trail"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config organization aggregator"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty organization"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_access_analyzer" {
  description = "Enable AWS Access Analyzer"
  type        = bool
  default     = true
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

# Compliance and Data Management
variable "data_classification" {
  description = "Data classification level"
  type        = string
  default     = "confidential"
  
  validation {
    condition = contains([
      "public", "internal", "confidential", "restricted"
    ], var.data_classification)
    error_message = "Data classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 365
}

# Cross-Account Role Configuration
variable "assume_role_arn" {
  description = "ARN of the role to assume for deployment"
  type        = string
  default     = null
}

variable "external_id" {
  description = "External ID for assume role"
  type        = string
  default     = null
  sensitive   = true
}
