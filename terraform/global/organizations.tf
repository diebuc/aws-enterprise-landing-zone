# AWS Organizations configuration for Enterprise Landing Zone
# This module sets up the organizational structure with proper governance

# Local variables for organization configuration
locals {
  organization_config = {
    feature_set = "ALL"
    enabled_policy_types = [
      "SERVICE_CONTROL_POLICY",
      "TAG_POLICY",
      "BACKUP_POLICY",
      "AISERVICES_OPT_OUT_POLICY"
    ]
  }

  # Standard organizational units structure
  organizational_units = {
    security = {
      name = "Security"
      accounts = [
        {
          name  = "security-prod"
          email = "aws-security-prod@${var.organization_domain}"
        }
      ]
    }
    shared_services = {
      name = "Shared Services"  
      accounts = [
        {
          name  = "shared-services-prod"
          email = "aws-shared-services-prod@${var.organization_domain}"
        }
      ]
    }
    workloads = {
      name = "Workloads"
      accounts = [
        {
          name  = "workload-prod-1"
          email = "aws-workload-prod-1@${var.organization_domain}"
        },
        {
          name  = "workload-staging-1" 
          email = "aws-workload-staging-1@${var.organization_domain}"
        }
      ]
    }
  }
}

# AWS Organizations - Enable all features
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com", 
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "controltower.amazonaws.com",
    "account.amazonaws.com",
    "backup.amazonaws.com"
  ]

  enabled_policy_types = local.organization_config.enabled_policy_types
  feature_set         = local.organization_config.feature_set

  tags = merge(local.common_tags, {
    Name = "${var.organization_name} Organization"
    Type = "organization"
  })
}

# Create Organizational Units
resource "aws_organizations_organizational_unit" "main" {
  for_each  = local.organizational_units
  name      = each.value.name
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(local.common_tags, {
    Name = each.value.name
    Type = "organizational-unit"
  })
}

# Create accounts within each OU (commented out for cost safety)
# Uncomment when ready to deploy actual accounts
/*
resource "aws_organizations_account" "accounts" {
  for_each = merge([
    for ou_key, ou_value in local.organizational_units : {
      for account in ou_value.accounts :
      "${ou_key}-${account.name}" => {
        name     = account.name
        email    = account.email
        ou_id    = aws_organizations_organizational_unit.main[ou_key].id
        ou_name  = ou_value.name
      }
    }
  ]...)

  name      = each.value.name
  email     = each.value.email
  parent_id = each.value.ou_id
  role_name = "OrganizationAccountAccessRole"

  # Prevent accidental account deletion
  close_on_deletion = false

  tags = merge(local.common_tags, {
    Name           = each.value.name
    OrganizationOU = each.value.ou_name
    AccountType    = split("-", each.value.name)[0]
    Environment    = length(split("-", each.value.name)) > 1 ? split("-", each.value.name)[1] : "unknown"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes = [role_name]
  }
}
*/

# Service Control Policies - Security Baseline
resource "aws_organizations_policy" "security_baseline" {
  name        = "SecurityBaselinePolicy"
  description = "Baseline security controls for all accounts in the organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Prevent root user actions
      {
        Sid       = "PreventRootUserActions"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey", 
          "iam:UpdateAccessKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:userid" = "ROOT"
          }
        }
      },
      # Prevent disabling of security services
      {
        Sid    = "PreventSecurityServiceDisabling"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "config:DeleteConfigurationRecorder",
          "config:StopConfigurationRecorder",
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalOrgID" = aws_organizations_organization.main.id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "Security Baseline SCP"
    PolicyType  = "preventive-control"
    Scope       = "organization-wide"
  })
}

# Attach Security Policy to Root
resource "aws_organizations_policy_attachment" "security_baseline_root" {
  policy_id = aws_organizations_policy.security_baseline.id
  target_id = aws_organizations_organization.main.roots[0].id
}

# Output values for use in other modules
output "organization_id" {
  description = "The identifier of the organization"
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "The Amazon Resource Name (ARN) of the organization"
  value       = aws_organizations_organization.main.arn
}

output "organization_root_id" {
  description = "The identifier of the root of this organization"
  value       = aws_organizations_organization.main.roots[0].id
}

output "organizational_units" {
  description = "Map of organizational unit names to their IDs"
  value = {
    for k, v in aws_organizations_organizational_unit.main : k => {
      id   = v.id
      arn  = v.arn
      name = v.name
    }
  }
}
