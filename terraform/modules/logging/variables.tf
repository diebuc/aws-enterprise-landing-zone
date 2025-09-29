# Variables for Logging Module

variable "organization_name" {
  description = "Name of the organization"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# S3 Bucket Configuration
#------------------------------------------------------------------------------

variable "centralized_logging_bucket_name" {
  description = "Name for centralized logging S3 bucket (auto-generated if not provided)"
  type        = string
  default     = null
}

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for logs"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Log Retention Policies
#------------------------------------------------------------------------------

variable "cloudtrail_retention_days" {
  description = "Number of days to retain CloudTrail logs in S3"
  type        = number
  default     = 2555  # 7 years for compliance
}

variable "config_retention_days" {
  description = "Number of days to retain Config logs in S3"
  type        = number
  default     = 2555  # 7 years for compliance
}

variable "vpc_flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs in S3"
  type        = number
  default     = 90
}

variable "elb_logs_retention_days" {
  description = "Number of days to retain ELB logs in S3"
  type        = number
  default     = 60
}

variable "cloudwatch_logs_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 365
}

variable "security_logs_retention_days" {
  description = "Number of days to retain security event logs"
  type        = number
  default     = 731  # 2 years
}

variable "application_logs_retention_days" {
  description = "Number of days to retain application logs"
  type        = number
  default     = 90
}

#------------------------------------------------------------------------------
# Application Logs
#------------------------------------------------------------------------------

variable "enable_application_logs" {
  description = "Enable centralized application logs"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# ELB Account ID for Access Logs
#------------------------------------------------------------------------------

variable "elb_account_id" {
  description = "AWS ELB service account ID for the region (for ELB access logs)"
  type        = string
  default     = "127311923021"  # us-east-1, update per region
}

#------------------------------------------------------------------------------
# Security Alarms
#------------------------------------------------------------------------------

variable "enable_security_alarms" {
  description = "Enable CloudWatch alarms for security events"
  type        = bool
  default     = true
}

variable "security_alerts_email" {
  description = "Email address for security alerts"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Dashboard and Queries
#------------------------------------------------------------------------------

variable "enable_dashboard" {
  description = "Enable CloudWatch dashboard for security operations"
  type        = bool
  default     = true
}

variable "enable_log_insights_queries" {
  description = "Create saved CloudWatch Log Insights queries"
  type        = bool
  default     = true
}
