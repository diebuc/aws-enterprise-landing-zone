# CloudWatch Dashboard for Landing Zone Monitoring
resource "aws_cloudwatch_dashboard" "landing_zone" {
  dashboard_name = "${var.organization_name}-landing-zone-overview"

  dashboard_body = jsonencode({
    widgets = [
      # Security Metrics Row
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/GuardDuty", "FindingsCount", { stat = "Sum", label = "GuardDuty Findings" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "GuardDuty Findings (Last 24h)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 8
        height = 6
        x      = 0
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SecurityHub", "Findings", { stat = "Sum", label = "Security Hub Findings" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Security Hub Findings"
        }
        width  = 8
        height = 6
        x      = 8
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Config", "ComplianceScore", { stat = "Average", label = "Config Compliance %" }]
          ]
          period = 3600
          stat   = "Average"
          region = var.aws_region
          title  = "AWS Config Compliance Score"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        width  = 8
        height = 6
        x      = 16
        y      = 0
      },

      # Network Traffic Row
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/TransitGateway", "BytesIn", { stat = "Sum", label = "Bytes In" }],
            [".", "BytesOut", { stat = "Sum", label = "Bytes Out" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Transit Gateway Traffic"
        }
        width  = 12
        height = 6
        x      = 0
        y      = 6
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/NATGateway", "BytesOutToDestination", { stat = "Sum", label = "NAT Gateway Egress" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "NAT Gateway Traffic"
        }
        width  = 12
        height = 6
        x      = 12
        y      = 6
      },

      # Cost and Usage Row
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", { stat = "Maximum", label = "Estimated Monthly Charges" }]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1"
          title  = "Estimated AWS Costs"
        }
        width  = 12
        height = 6
        x      = 0
        y      = 12
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/lambda/cost-optimizer' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region  = var.aws_region
          stacked = false
          title   = "Cost Optimization Logs"
          view    = "table"
        }
        width  = 12
        height = 6
        x      = 12
        y      = 12
      }
    ]
  })
}

# CloudWatch Alarms for Critical Security Events
resource "aws_cloudwatch_metric_alarm" "guardduty_high_severity" {
  alarm_name          = "${var.organization_name}-guardduty-high-severity-findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FindingsCount"
  namespace           = "AWS/GuardDuty"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when GuardDuty detects high severity findings"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    Severity = "High"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.organization_name}-guardduty-alarm"
      Compliance  = "Security-Monitoring"
      Severity    = "High"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "config_noncompliant" {
  alarm_name          = "${var.organization_name}-config-noncompliant-resources"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "NonCompliantResourceCount"
  namespace           = "AWS/Config"
  period              = 3600
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Alert when AWS Config detects multiple non-compliant resources"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]

  tags = merge(
    var.tags,
    {
      Name       = "${var.organization_name}-config-compliance-alarm"
      Compliance = "Config-Monitoring"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  alarm_name          = "${var.organization_name}-root-account-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "CloudTrailMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "CRITICAL: Root account usage detected"
  alarm_actions       = [aws_sns_topic.critical_security_alerts.arn]

  tags = merge(
    var.tags,
    {
      Name     = "${var.organization_name}-root-usage-alarm"
      Severity = "Critical"
    }
  )
}

# SNS Topics for Alerts
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.organization_name}-security-alerts"
  display_name      = "Security Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-security-alerts"
      Purpose = "Security Monitoring"
    }
  )
}

resource "aws_sns_topic" "compliance_alerts" {
  name              = "${var.organization_name}-compliance-alerts"
  display_name      = "Compliance Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-compliance-alerts"
      Purpose = "Compliance Monitoring"
    }
  )
}

resource "aws_sns_topic" "critical_security_alerts" {
  name              = "${var.organization_name}-critical-security"
  display_name      = "CRITICAL Security Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name     = "${var.organization_name}-critical-alerts"
      Severity = "Critical"
    }
  )
}

# SNS Topic Subscriptions (Email)
resource "aws_sns_topic_subscription" "security_email" {
  count     = length(var.security_email_addresses)
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_email_addresses[count.index]
}

resource "aws_sns_topic_subscription" "compliance_email" {
  count     = length(var.compliance_email_addresses)
  topic_arn = aws_sns_topic.compliance_alerts.arn
  protocol  = "email"
  endpoint  = var.compliance_email_addresses[count.index]
}

resource "aws_sns_topic_subscription" "critical_email" {
  count     = length(var.critical_alert_email_addresses)
  topic_arn = aws_sns_topic.critical_security_alerts.arn
  protocol  = "email"
  endpoint  = var.critical_alert_email_addresses[count.index]
}

# CloudWatch Log Metric Filter for Root Account Usage
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  name           = "${var.organization_name}-root-account-usage"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

# CloudWatch Log Metric Filter for Unauthorized API Calls
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "${var.organization_name}-unauthorized-api-calls"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.organization_name}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert on multiple unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = merge(
    var.tags,
    {
      Name = "${var.organization_name}-unauthorized-calls-alarm"
    }
  )
}

# CloudWatch Composite Alarm for Security Posture
resource "aws_cloudwatch_composite_alarm" "security_posture" {
  alarm_name          = "${var.organization_name}-overall-security-posture"
  alarm_description   = "Composite alarm for overall security posture"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.critical_security_alerts.arn]
  ok_actions          = [aws_sns_topic.security_alerts.arn]
  
  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.guardduty_high_severity.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.root_account_usage.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.unauthorized_api_calls.alarm_name})"
  ])

  tags = merge(
    var.tags,
    {
      Name     = "${var.organization_name}-security-posture"
      Critical = "true"
    }
  )
}
