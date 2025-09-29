# Logging Module for AWS Enterprise Landing Zone
# Centralized logging and monitoring across all accounts

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local values
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  common_tags = merge(var.tags, {
    Module    = "logging"
    ManagedBy = "terraform"
  })
}

#------------------------------------------------------------------------------
# Centralized Logging S3 Bucket
#------------------------------------------------------------------------------

resource "aws_s3_bucket" "centralized_logging" {
  bucket = var.centralized_logging_bucket_name != null ? var.centralized_logging_bucket_name : "${var.organization_name}-central-logs-${local.account_id}"

  tags = merge(local.common_tags, {
    Name = "centralized-logging-bucket"
    Type = "logging-storage"
  })
}

# Enable versioning for audit trail
resource "aws_s3_bucket_versioning" "centralized_logging" {
  bucket = aws_s3_bucket.centralized_logging.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "centralized_logging" {
  bucket = aws_s3_bucket.centralized_logging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "centralized_logging" {
  bucket = aws_s3_bucket.centralized_logging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms_encryption ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms_encryption ? aws_kms_key.logging[0].arn : null
    }
    bucket_key_enabled = var.enable_kms_encryption
  }
}

# Lifecycle policy for log retention and cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "centralized_logging" {
  bucket = aws_s3_bucket.centralized_logging.id

  rule {
    id     = "cloudtrail-logs"
    status = "Enabled"

    filter {
      prefix = "cloudtrail/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = var.cloudtrail_retention_days
    }
  }

  rule {
    id     = "config-logs"
    status = "Enabled"

    filter {
      prefix = "config/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.config_retention_days
    }
  }

  rule {
    id     = "vpc-flow-logs"
    status = "Enabled"

    filter {
      prefix = "vpcflowlogs/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = var.vpc_flow_logs_retention_days
    }
  }

  rule {
    id     = "load-balancer-logs"
    status = "Enabled"

    filter {
      prefix = "elb/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = var.elb_logs_retention_days
    }
  }
}

# S3 bucket policy for cross-account logging
resource "aws_s3_bucket_policy" "centralized_logging" {
  bucket = aws_s3_bucket.centralized_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudTrail access
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.centralized_logging.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.centralized_logging.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # Config access
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.centralized_logging.arn
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.centralized_logging.arn
      },
      {
        Sid    = "AWSConfigWrite"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.centralized_logging.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # VPC Flow Logs access
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.centralized_logging.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.centralized_logging.arn
      },
      # ELB Logs access
      {
        Sid    = "AWSLogDeliveryWriteELB"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${var.elb_account_id}:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.centralized_logging.arn}/*"
      }
    ]
  })
}

#------------------------------------------------------------------------------
# KMS Key for Log Encryption (Optional)
#------------------------------------------------------------------------------

resource "aws_kms_key" "logging" {
  count               = var.enable_kms_encryption ? 1 : 0
  description         = "KMS key for centralized logging encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "centralized-logging-kms-key"
    Type = "encryption-key"
  })
}

resource "aws_kms_alias" "logging" {
  count         = var.enable_kms_encryption ? 1 : 0
  name          = "alias/${var.organization_name}-logging"
  target_key_id = aws_kms_key.logging[0].key_id
}

#------------------------------------------------------------------------------
# CloudWatch Log Groups
#------------------------------------------------------------------------------

# Organization-wide CloudWatch Log Group
resource "aws_cloudwatch_log_group" "organization" {
  name              = "/aws/organization/${var.organization_name}"
  retention_in_days = var.cloudwatch_logs_retention_days
  kms_key_id        = var.enable_kms_encryption ? aws_kms_key.logging[0].arn : null

  tags = merge(local.common_tags, {
    Name = "organization-log-group"
    Type = "cloudwatch-logs"
  })
}

# Security events log group
resource "aws_cloudwatch_log_group" "security_events" {
  name              = "/aws/security/${var.organization_name}"
  retention_in_days = var.security_logs_retention_days
  kms_key_id        = var.enable_kms_encryption ? aws_kms_key.logging[0].arn : null

  tags = merge(local.common_tags, {
    Name = "security-events-log-group"
    Type = "security-logs"
  })
}

# Application logs aggregation
resource "aws_cloudwatch_log_group" "applications" {
  count             = var.enable_application_logs ? 1 : 0
  name              = "/aws/applications/${var.organization_name}"
  retention_in_days = var.application_logs_retention_days
  kms_key_id        = var.enable_kms_encryption ? aws_kms_key.logging[0].arn : null

  tags = merge(local.common_tags, {
    Name = "applications-log-group"
    Type = "application-logs"
  })
}

#------------------------------------------------------------------------------
# CloudWatch Metric Filters for Security Events
#------------------------------------------------------------------------------

# Root account usage
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "root-account-usage"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "{ ($.userIdentity.type = \"Root\") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != \"AwsServiceEvent\") }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "Security/IAM"
    value     = "1"
  }
}

# Unauthorized API calls
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "unauthorized-api-calls"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "Security/API"
    value     = "1"
  }
}

# Console sign-in failures
resource "aws_cloudwatch_log_metric_filter" "console_signin_failures" {
  name           = "console-signin-failures"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "{ ($.eventName = \"ConsoleLogin\") && ($.errorMessage = \"Failed authentication\") }"

  metric_transformation {
    name      = "ConsoleSignInFailures"
    namespace = "Security/IAM"
    value     = "1"
  }
}

# IAM policy changes
resource "aws_cloudwatch_log_metric_filter" "iam_policy_changes" {
  name           = "iam-policy-changes"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = CreatePolicyVersion) || ($.eventName = DeletePolicyVersion) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachGroupPolicy) }"

  metric_transformation {
    name      = "IAMPolicyChanges"
    namespace = "Security/IAM"
    value     = "1"
  }
}

# Security group changes
resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  name           = "security-group-changes"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "Security/Network"
    value     = "1"
  }
}

# Network ACL changes
resource "aws_cloudwatch_log_metric_filter" "network_acl_changes" {
  name           = "network-acl-changes"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "{ ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }"

  metric_transformation {
    name      = "NetworkACLChanges"
    namespace = "Security/Network"
    value     = "1"
  }
}

#------------------------------------------------------------------------------
# CloudWatch Alarms for Security Metrics
#------------------------------------------------------------------------------

# SNS topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  count = var.enable_security_alarms ? 1 : 0
  name  = "${var.organization_name}-security-alerts"

  kms_master_key_id = var.enable_kms_encryption ? aws_kms_key.logging[0].id : null

  tags = merge(local.common_tags, {
    Name = "security-alerts-topic"
    Type = "sns-topic"
  })
}

# Email subscription for security alerts
resource "aws_sns_topic_subscription" "security_alerts_email" {
  count     = var.enable_security_alarms && var.security_alerts_email != null ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alerts_email
}

# Root account usage alarm
resource "aws_cloudwatch_metric_alarm" "root_usage" {
  count               = var.enable_security_alarms ? 1 : 0
  alarm_name          = "${var.organization_name}-root-account-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "Security/IAM"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alerts when root account is used"
  alarm_actions       = [aws_sns_topic.security_alerts[0].arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.common_tags, {
    Name     = "root-usage-alarm"
    Severity = "critical"
  })
}

# Unauthorized API calls alarm
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  count               = var.enable_security_alarms ? 1 : 0
  alarm_name          = "${var.organization_name}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "Security/API"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alerts on multiple unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts[0].arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.common_tags, {
    Name     = "unauthorized-calls-alarm"
    Severity = "high"
  })
}

# Console sign-in failures alarm
resource "aws_cloudwatch_metric_alarm" "console_signin_failures" {
  count               = var.enable_security_alarms ? 1 : 0
  alarm_name          = "${var.organization_name}-console-signin-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsoleSignInFailures"
  namespace           = "Security/IAM"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Alerts on multiple console sign-in failures"
  alarm_actions       = [aws_sns_topic.security_alerts[0].arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.common_tags, {
    Name     = "signin-failures-alarm"
    Severity = "medium"
  })
}

#------------------------------------------------------------------------------
# CloudWatch Dashboard
#------------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "security_operations" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "${var.organization_name}-security-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["Security/IAM", "RootAccountUsage", { stat = "Sum", label = "Root Account Usage" }],
            ["Security/API", "UnauthorizedAPICalls", { stat = "Sum", label = "Unauthorized API Calls" }],
            ["Security/IAM", "ConsoleSignInFailures", { stat = "Sum", label = "Console Sign-in Failures" }],
            ["Security/IAM", "IAMPolicyChanges", { stat = "Sum", label = "IAM Policy Changes" }]
          ]
          period = 300
          stat   = "Sum"
          region = local.region
          title  = "Security Events"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["Security/Network", "SecurityGroupChanges", { stat = "Sum", label = "Security Group Changes" }],
            ["Security/Network", "NetworkACLChanges", { stat = "Sum", label = "Network ACL Changes" }]
          ]
          period = 300
          stat   = "Sum"
          region = local.region
          title  = "Network Security Changes"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.security_events.name}' | fields @timestamp, eventName, userIdentity.type, sourceIPAddress | filter eventName like /Delete|Put|Create/ | sort @timestamp desc | limit 20"
          region  = local.region
          title   = "Recent Security Events"
          stacked = false
        }
      }
    ]
  })
}

#------------------------------------------------------------------------------
# Log Insights Queries (Saved Queries)
#------------------------------------------------------------------------------

resource "aws_cloudwatch_query_definition" "failed_auth_attempts" {
  count = var.enable_log_insights_queries ? 1 : 0
  name  = "${var.organization_name}/failed-authentication-attempts"

  log_group_names = [
    aws_cloudwatch_log_group.security_events.name
  ]

  query_string = <<-QUERY
    fields @timestamp, userIdentity.principalId, sourceIPAddress, errorMessage
    | filter eventName = "ConsoleLogin" and errorMessage = "Failed authentication"
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "root_account_activity" {
  count = var.enable_log_insights_queries ? 1 : 0
  name  = "${var.organization_name}/root-account-activity"

  log_group_names = [
    aws_cloudwatch_log_group.security_events.name
  ]

  query_string = <<-QUERY
    fields @timestamp, eventName, sourceIPAddress, userAgent
    | filter userIdentity.type = "Root"
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "iam_changes" {
  count = var.enable_log_insights_queries ? 1 : 0
  name  = "${var.organization_name}/iam-policy-changes"

  log_group_names = [
    aws_cloudwatch_log_group.security_events.name
  ]

  query_string = <<-QUERY
    fields @timestamp, eventName, userIdentity.principalId, requestParameters
    | filter eventName in ["PutUserPolicy", "PutRolePolicy", "PutGroupPolicy", "AttachUserPolicy", "AttachRolePolicy", "AttachGroupPolicy", "DeleteUserPolicy", "DeleteRolePolicy", "DeleteGroupPolicy"]
    | sort @timestamp desc
    | limit 100
  QUERY
}
