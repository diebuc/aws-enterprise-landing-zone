# Monitoring Module

Comprehensive CloudWatch monitoring module for AWS Landing Zone.

## Features

### CloudWatch Dashboard
- **Security Metrics**: GuardDuty findings, Security Hub alerts, Config compliance
- **Network Traffic**: Transit Gateway throughput, NAT Gateway usage
- **Cost Monitoring**: Daily spend tracking and budget alerts
- **Log Insights**: Quick access to cost optimization and security logs

### CloudWatch Alarms
- **GuardDuty High Severity**: Alerts on critical threat detections
- **Config Non-Compliance**: Alerts when resources violate compliance rules
- **Root Account Usage**: CRITICAL alert on root account activity
- **Unauthorized API Calls**: Alerts on access denied patterns
- **Composite Security Posture**: Overall security status alarm

### SNS Topics
- **Security Alerts**: Standard security notifications (P2-P3)
- **Compliance Alerts**: Config and compliance violations
- **Critical Alerts**: Immediate action required (P1)

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  organization_name        = "my-company"
  aws_region              = "us-east-1"
  kms_key_id              = aws_kms_key.monitoring.id
  cloudtrail_log_group_name = "/aws/cloudtrail/organization"

  security_email_addresses = [
    "security-team@example.com",
    "devops@example.com"
  ]

  compliance_email_addresses = [
    "compliance@example.com",
    "audit@example.com"
  ]

  critical_alert_email_addresses = [
    "oncall@example.com",
    "security-critical@example.com"
  ]

  alert_thresholds = {
    guardduty_findings     = 1
    config_noncompliant    = 10
    unauthorized_api_calls = 5
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "monitoring"
  }
}
```

## Outputs

| Output | Description |
|--------|-------------|
| `dashboard_name` | Name of the CloudWatch dashboard |
| `dashboard_url` | Direct URL to view the dashboard |
| `security_alerts_topic_arn` | SNS topic ARN for security alerts |
| `compliance_alerts_topic_arn` | SNS topic ARN for compliance alerts |
| `critical_alerts_topic_arn` | SNS topic ARN for critical alerts |

## CloudWatch Dashboard Widgets

### Row 1: Security Metrics
- **GuardDuty Findings (Last 24h)**: Sum of threat detections
- **Security Hub Findings**: Centralized security alerts
- **Config Compliance Score**: Percentage of compliant resources

### Row 2: Network Traffic
- **Transit Gateway Traffic**: Bytes in/out across VPC attachments
- **NAT Gateway Traffic**: Egress traffic to internet

### Row 3: Cost & Logs
- **Estimated AWS Costs**: Daily cost tracking
- **Cost Optimization Logs**: Recent cost-saving actions

## Alert Severity Levels

| Level | Response Time | Examples |
|-------|--------------|----------|
| **P1 - Critical** | 5 minutes | Root account usage, active data exfiltration |
| **P2 - High** | 30 minutes | High severity GuardDuty findings, privilege escalation |
| **P3 - Medium** | 2 hours | Config violations, multiple unauthorized calls |
| **P4 - Low** | 24 hours | Informational compliance findings |

## Cost Considerations

### Monthly Costs (10 accounts)
- CloudWatch Dashboards: $3/dashboard = **$3/month**
- CloudWatch Alarms: $0.10/alarm × 10 = **$1/month**
- SNS Topics: $0.50/million notifications = **~$1/month**
- Log Metric Filters: $0.50/filter = **$2/month**
- **Total: ~$7/month**

### Cost Optimization
- Use log metric filters instead of custom Lambda functions
- Consolidate alarms where possible
- Set appropriate evaluation periods to reduce false positives
- Use composite alarms to reduce SNS notification costs

## Customization

### Adding Custom Metrics

```hcl
resource "aws_cloudwatch_metric_alarm" "custom_alarm" {
  alarm_name          = "${var.organization_name}-custom-metric"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "YourCustomMetric"
  namespace           = "YourNamespace"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

### Adding Dashboard Widgets

Edit `main.tf` and add to the `widgets` array:

```json
{
  "type": "metric",
  "properties": {
    "metrics": [
      ["Namespace", "MetricName", {"stat": "Sum"}]
    ],
    "period": 300,
    "stat": "Sum",
    "region": "us-east-1",
    "title": "Your Widget Title"
  },
  "width": 12,
  "height": 6,
  "x": 0,
  "y": 18
}
```

## Integration with Other Modules

### With Logging Module
```hcl
module "monitoring" {
  source = "./modules/monitoring"
  
  cloudtrail_log_group_name = module.logging.cloudtrail_log_group_name
  kms_key_id                = module.logging.kms_key_id
}
```

### With Security Module
```hcl
# Security module exports GuardDuty detector ID
# Monitoring module creates alarms based on GuardDuty metrics
```

## Troubleshooting

### SNS Email Not Receiving Alerts
1. Check spam folder for confirmation email
2. Verify subscription is confirmed in AWS Console
3. Check SNS topic policy allows publishing

### Dashboard Not Showing Data
1. Verify metrics are being published to CloudWatch
2. Check IAM permissions for CloudWatch
3. Confirm correct region is selected

### Alarms in INSUFFICIENT_DATA State
- Metrics may not be published yet
- Wait 15-30 minutes for initial data points
- Verify source services are enabled (GuardDuty, Config)

## Best Practices

1. **Email Lists**: Use distribution lists instead of individual emails
2. **On-Call Rotation**: Integrate critical alerts with PagerDuty/Opsgenie
3. **Regular Review**: Review and tune alarm thresholds quarterly
4. **Documentation**: Keep runbooks for each alarm type
5. **Testing**: Test alert delivery monthly with synthetic events

## References

- [CloudWatch Dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [SNS Best Practices](https://docs.aws.amazon.com/sns/latest/dg/sns-best-practices.html)
