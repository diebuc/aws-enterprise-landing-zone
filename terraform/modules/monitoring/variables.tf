variable "organization_name" {
  description = "Name of the organization for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region for monitoring resources"
  type        = string
  default     = "us-east-1"
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting SNS topics"
  type        = string
}

variable "cloudtrail_log_group_name" {
  description = "CloudWatch Log Group name for CloudTrail logs"
  type        = string
}

variable "security_email_addresses" {
  description = "Email addresses for security alerts"
  type        = list(string)
  default     = []
}

variable "compliance_email_addresses" {
  description = "Email addresses for compliance alerts"
  type        = list(string)
  default     = []
}

variable "critical_alert_email_addresses" {
  description = "Email addresses for critical security alerts (24/7 on-call)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all monitoring resources"
  type        = map(string)
  default     = {}
}

variable "enable_billing_alerts" {
  description = "Enable billing and cost alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD for cost alerts"
  type        = number
  default     = 5000
}

variable "alert_thresholds" {
  description = "Custom alert thresholds for various metrics"
  type = object({
    guardduty_findings    = number
    config_noncompliant   = number
    unauthorized_api_calls = number
  })
  default = {
    guardduty_findings     = 1
    config_noncompliant    = 10
    unauthorized_api_calls = 5
  }
}

variable "cost_alert_email_addresses" {
  description = "Email addresses for cost and budget alerts"
  type        = list(string)
  default     = []
}

variable "monitored_account_ids" {
  description = "List of AWS account IDs to monitor for cost"
  type        = list(string)
  default     = []
}
