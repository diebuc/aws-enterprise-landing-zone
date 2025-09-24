# Terraform configuration for AWS Enterprise Landing Zone
# Providers and backend configuration

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }

  # Backend configuration - uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "landing-zone/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  default_tags {
    tags = {
      Environment     = var.environment
      Project         = var.project_name
      ManagedBy       = "terraform"
      SecurityLevel   = "high"
      ComplianceScope = join(",", var.compliance_frameworks)
      CostCenter      = var.cost_center
      Owner           = var.owner_email
    }
  }

  # Assume role configuration for cross-account deployment
  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "TerraformLandingZoneSession"
    external_id  = var.external_id
  }
}

# Random provider for generating unique identifiers
provider "random" {}

# Local provider for file operations
provider "local" {}

# Null provider for resource lifecycle management
provider "null" {}

# Data sources for current AWS context
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local values for common configurations
locals {
  # Account information
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  # Common resource naming
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags to be applied in addition to provider default tags
  common_tags = {
    CreatedBy       = data.aws_caller_identity.current.arn
    Region          = local.region
    AccountId       = local.account_id
    TerraformPath   = path.cwd
    LastUpdated     = timestamp()
  }

  # Security configuration
  security_config = {
    enable_cloudtrail     = var.enable_cloudtrail
    enable_config         = var.enable_config
    enable_guardduty      = var.enable_guardduty
    enable_security_hub   = var.enable_security_hub
    enable_access_analyzer = var.enable_access_analyzer
  }

  # Network configuration
  network_config = {
    vpc_cidr               = var.vpc_cidr
    availability_zones     = var.availability_zones
    enable_nat_gateway     = var.enable_nat_gateway
    enable_vpn_gateway     = var.enable_vpn_gateway
    enable_dns_hostnames   = true
    enable_dns_support     = true
  }

  # Compliance and governance
  compliance_config = {
    frameworks              = var.compliance_frameworks
    data_classification     = var.data_classification
    backup_retention_days   = var.backup_retention_days
    log_retention_days      = var.log_retention_days
  }
}
