# Outputs for Logging Module

output "centralized_logging_bucket_id" {
  description = "ID of the centralized logging S3 bucket"
  value       = aws_s3_bucket.centralized_logging.id
}

output "centralized_logging_bucket_arn" {
  description = "ARN of the centralized logging S3 bucket"
  value       = aws_s3_bucket.centralized_logging.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for log encryption"
  value       = try(aws_kms_key.logging[0].id, null)
}

output "kms_key_arn" {
  description = "ARN of the KMS key for log encryption"
  value       = try(aws_kms_key.logging[0].arn, null)
}

output "organization_log_group_name" {
  description = "Name of the organization CloudWatch log group"
  value       = aws_cloudwatch_log_group.organization.name
}

output "organization_log_group_arn" {
  description = "ARN of the organization CloudWatch log group"
  value       = aws_cloudwatch_log_group.organization.arn
}

output "security_events_log_group_name" {
  description = "Name of the security events CloudWatch log group"
  value       = aws_cloudwatch_log_group.security_events.name
}

output "security_events_log_group_arn" {
  description = "ARN of the security events CloudWatch log group"
  value       = aws_cloudwatch_log_group.security_events.arn
}

output "security_alerts_topic_arn" {
  description = "ARN of the SNS topic for security alerts"
  value       = try(aws_sns_topic.security_alerts[0].arn, null)
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = try(aws_cloudwatch_dashboard.security_operations[0].dashboard_name, null)
}
