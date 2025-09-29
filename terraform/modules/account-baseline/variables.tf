# Variables for Account Baseline Module

variable "account_name" {
  description = "Name of the AWS account"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# AWS Config
#------------------------------------------------------------------------------

variable "enable_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = true
}

variable "config_s3_bucket_name" {
  description = "Name of S3 bucket for Config (uses centralized bucket if provided)"
  type        = string
  default     = null
}

variable "config_include_global_resources" {
  description = "Include global resources in Config recording"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# CloudTrail
#------------------------------------------------------------------------------

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "Name of S3 bucket for CloudTrail (uses centralized bucket if provided)"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# GuardDuty
#------------------------------------------------------------------------------

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "guardduty_finding_publishing_frequency" {
  description = "Frequency of GuardDuty finding updates"
  type        = string
  default     = "FIFTEEN_MINUTES"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_publishing_frequency)
    error_message = "Must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "guardduty_enable_s3_logs" {
  description = "Enable S3 protection in GuardDuty"
  type        = bool
  default     = true
}

variable "guardduty_enable_kubernetes" {
  description = "Enable Kubernetes protection in GuardDuty"
  type        = bool
  default     = false
}

variable "guardduty_enable_malware_protection" {
  description = "Enable malware protection in GuardDuty"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# IAM
#------------------------------------------------------------------------------

variable "enable_iam_password_policy" {
  description = "Enable strict IAM password policy"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# EBS Encryption
#------------------------------------------------------------------------------

variable "enable_ebs_encryption_by_default" {
  description = "Enable EBS encryption by default"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# S3 Account Settings
#------------------------------------------------------------------------------

variable "enable_s3_account_public_access_block" {
  description = "Enable account-level S3 public access block"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Security Hub
#------------------------------------------------------------------------------

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "security_hub_enable_default_standards" {
  description = "Enable default Security Hub standards"
  type        = bool
  default     = true
}

variable "security_hub_enable_cis" {
  description = "Enable CIS AWS Foundations Benchmark"
  type        = bool
  default     = true
}

variable "security_hub_enable_fsbp" {
  description = "Enable AWS Foundational Security Best Practices"
  type        = bool
  default     = true
}

variable "security_hub_enable_pci_dss" {
  description = "Enable PCI DSS standard"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# IAM Access Analyzer
#------------------------------------------------------------------------------

variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# AWS Backup
#------------------------------------------------------------------------------

variable "enable_aws_backup" {
  description = "Enable AWS Backup with default backup plan"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 35
}

#------------------------------------------------------------------------------
# CloudWatch Alarms
#------------------------------------------------------------------------------

variable "enable_cloudwatch_alarms" {
  description = "Enable account-level CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arn" {
  description = "ARN of SNS topic for alarms (creates new topic if not provided)"
  type        = string
  default     = null
}
