# Outputs for Account Baseline Module

output "config_recorder_id" {
  description = "ID of the Config configuration recorder"
  value       = try(aws_config_configuration_recorder.main[0].id, null)
}

output "cloudtrail_id" {
  description = "ID of the CloudTrail"
  value       = try(aws_cloudtrail.main[0].id, null)
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = try(aws_cloudtrail.main[0].arn, null)
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = try(aws_guardduty_detector.main[0].id, null)
}

output "security_hub_arn" {
  description = "ARN of Security Hub"
  value       = try(aws_securityhub_account.main[0].arn, null)
}

output "access_analyzer_arn" {
  description = "ARN of IAM Access Analyzer"
  value       = try(aws_accessanalyzer_analyzer.account[0].arn, null)
}

output "backup_vault_arn" {
  description = "ARN of the backup vault"
  value       = try(aws_backup_vault.default[0].arn, null)
}

output "backup_plan_id" {
  description = "ID of the backup plan"
  value       = try(aws_backup_plan.default[0].id, null)
}

output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = try(aws_sns_topic.account_alarms[0].arn, var.alarm_sns_topic_arn)
}
