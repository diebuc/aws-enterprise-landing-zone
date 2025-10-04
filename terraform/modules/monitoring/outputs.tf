output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.landing_zone.dashboard_name
}

output "dashboard_url" {
  description = "URL to access the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.landing_zone.dashboard_name}"
}

output "security_alerts_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = aws_sns_topic.security_alerts.arn
}

output "compliance_alerts_topic_arn" {
  description = "ARN of the compliance alerts SNS topic"
  value       = aws_sns_topic.compliance_alerts.arn
}

output "critical_alerts_topic_arn" {
  description = "ARN of the critical security alerts SNS topic"
  value       = aws_sns_topic.critical_security_alerts.arn
}

output "guardduty_alarm_name" {
  description = "Name of the GuardDuty high severity alarm"
  value       = aws_cloudwatch_metric_alarm.guardduty_high_severity.alarm_name
}

output "config_compliance_alarm_name" {
  description = "Name of the Config compliance alarm"
  value       = aws_cloudwatch_metric_alarm.config_noncompliant.alarm_name
}

output "root_account_alarm_name" {
  description = "Name of the root account usage alarm"
  value       = aws_cloudwatch_metric_alarm.root_account_usage.alarm_name
}

output "security_posture_alarm_name" {
  description = "Name of the composite security posture alarm"
  value       = aws_cloudwatch_composite_alarm.security_posture.alarm_name
}

output "metric_filters" {
  description = "Map of CloudWatch log metric filters"
  value = {
    root_account_usage     = aws_cloudwatch_log_metric_filter.root_account_usage.name
    unauthorized_api_calls = aws_cloudwatch_log_metric_filter.unauthorized_api_calls.name
  }
}

output "cost_dashboard_name" {
  description = "Name of the cost monitoring dashboard"
  value       = aws_cloudwatch_dashboard.cost_monitoring.dashboard_name
}

output "cost_dashboard_url" {
  description = "URL to access the cost monitoring dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${aws_cloudwatch_dashboard.cost_monitoring.dashboard_name}"
}

output "monthly_budget_name" {
  description = "Name of the monthly cost budget"
  value       = aws_budgets_budget.monthly_cost.name
}

output "cost_alerts_topic_arn" {
  description = "ARN of the cost alerts SNS topic"
  value       = aws_sns_topic.cost_alerts.arn
}

output "anomaly_monitor_arn" {
  description = "ARN of the cost anomaly detection monitor"
  value       = aws_ce_anomaly_monitor.landing_zone.arn
}
