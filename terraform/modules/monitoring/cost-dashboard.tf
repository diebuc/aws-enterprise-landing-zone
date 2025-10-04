# Cost and Budget Monitoring Dashboard
resource "aws_cloudwatch_dashboard" "cost_monitoring" {
  dashboard_name = "${var.organization_name}-cost-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      # Current Month Cost
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", { stat = "Maximum", label = "Total Estimated Cost" }]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1"
          title  = "Current Month Estimated Costs"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      # Budget Status
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Budgets", "BudgetUtilization", { stat = "Average", label = "Budget Utilization %" }]
          ]
          period = 86400
          stat   = "Average"
          region = "us-east-1"
          title  = "Budget Utilization"
          yAxis = {
            left = {
              min = 0
              max = 120
            }
          }
          annotations = {
            horizontal = [
              {
                value = 80
                label = "Warning Threshold"
                color = "#FFA500"
              },
              {
                value = 100
                label = "Budget Limit"
                color = "#FF0000"
              }
            ]
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },

      # Cost by Service
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", { stat = "Maximum", dimensions = { ServiceName = "Amazon EC2" }, label = "EC2" }],
            ["...", { dimensions = { ServiceName = "Amazon RDS" }, label = "RDS" }],
            ["...", { dimensions = { ServiceName = "Amazon S3" }, label = "S3" }],
            ["...", { dimensions = { ServiceName = "AWS Transit Gateway" }, label = "Transit Gateway" }],
            ["...", { dimensions = { ServiceName = "Amazon CloudWatch" }, label = "CloudWatch" }],
            ["...", { dimensions = { ServiceName = "Amazon VPC" }, label = "VPC/NAT Gateway" }]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1"
          title  = "Cost by AWS Service"
        }
        width  = 24
        height = 6
        x      = 0
        y      = 6
      },

      # Data Transfer Costs
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", { 
              stat = "Maximum", 
              dimensions = { ServiceName = "AWS Data Transfer" }, 
              label = "Data Transfer Out" 
            }]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1"
          title  = "Data Transfer Costs"
        }
        width  = 12
        height = 6
        x      = 0
        y      = 12
      },

      # NAT Gateway Costs
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/NATGateway", "BytesOutToDestination", { stat = "Sum", label = "NAT Egress (Bytes)" }],
            [".", "BytesInFromDestination", { stat = "Sum", label = "NAT Ingress (Bytes)" }]
          ]
          period = 86400
          stat   = "Sum"
          region = var.aws_region
          title  = "NAT Gateway Traffic (Cost Driver)"
        }
        width  = 12
        height = 6
        x      = 12
        y      = 12
      },

      # Cost Trend (30 days)
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", { stat = "Maximum", label = "Daily Cost Trend" }]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1"
          title  = "30-Day Cost Trend"
          view   = "timeSeries"
          stacked = false
        }
        width  = 24
        height = 6
        x      = 0
        y      = 18
      }
    ]
  })
}

# AWS Budget for Monthly Spend
resource "aws_budgets_budget" "monthly_cost" {
  name              = "${var.organization_name}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_amount
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.cost_alert_email_addresses
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.cost_alert_email_addresses
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.cost_alert_email_addresses
  }

  cost_filters = {
    LinkedAccount = var.monitored_account_ids
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-monthly-budget"
      Purpose = "Cost Control"
    }
  )
}

# Budget for EC2 Spend (prevent runaway instances)
resource "aws_budgets_budget" "ec2_monthly" {
  name              = "${var.organization_name}-ec2-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_amount * 0.4  # 40% of total for EC2
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.cost_alert_email_addresses
  }

  cost_filters = {
    Service = "Amazon Elastic Compute Cloud - Compute"
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-ec2-budget"
      Service = "EC2"
    }
  )
}

# CloudWatch Alarm for Budget Breach
resource "aws_cloudwatch_metric_alarm" "budget_exceeded" {
  alarm_name          = "${var.organization_name}-budget-exceeded"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400
  statistic           = "Maximum"
  threshold           = var.monthly_budget_amount
  alarm_description   = "Alert when monthly costs exceed budget"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    Currency = "USD"
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-budget-alarm"
      Purpose = "Cost Control"
    }
  )
}

# SNS Topic for Cost Alerts
resource "aws_sns_topic" "cost_alerts" {
  name              = "${var.organization_name}-cost-alerts"
  display_name      = "Cost and Budget Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-cost-alerts"
      Purpose = "Cost Monitoring"
    }
  )
}

resource "aws_sns_topic_subscription" "cost_email" {
  count     = length(var.cost_alert_email_addresses)
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.cost_alert_email_addresses[count.index]
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_monitor" "landing_zone" {
  name              = "${var.organization_name}-cost-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-anomaly-monitor"
      Purpose = "Cost Anomaly Detection"
    }
  )
}

resource "aws_ce_anomaly_subscription" "landing_zone" {
  name      = "${var.organization_name}-cost-anomaly-subscription"
  frequency = "DAILY"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.landing_zone.arn
  ]

  subscriber {
    type    = "EMAIL"
    address = var.cost_alert_email_addresses[0]
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.organization_name}-anomaly-subscription"
      Purpose = "Cost Anomaly Alerts"
    }
  )
}
