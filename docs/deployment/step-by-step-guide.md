# Step-by-Step Deployment Guide

## Overview

This guide provides detailed instructions for deploying the AWS Enterprise Landing Zone. The deployment is divided into phases to minimize risk and allow for validation at each step.

**Estimated Total Time:** 4-6 hours for complete deployment

## Prerequisites

Before beginning deployment, ensure you have completed all items in the [Prerequisites Checklist](prerequisites.md).

## Deployment Phases

### Phase 1: Foundation Setup (Week 1)
- Management account configuration
- AWS Organizations setup
- Service Control Policies
- Initial account structure

### Phase 2: Security Baseline (Week 2)
- Security services enablement
- Centralized logging
- Compliance monitoring
- IAM configuration

### Phase 3: Network Infrastructure (Week 3)
- Transit Gateway deployment
- VPC creation and configuration
- Connectivity setup
- DNS configuration

### Phase 4: Account Provisioning (Week 4+)
- Workload account creation
- Baseline application
- Testing and validation

---

## Phase 1: Foundation Setup

### Step 1: Prepare Management Account

**Duration:** 30 minutes

#### 1.1 Enable MFA for Root Account

```bash
# Login to AWS Console as root user
# Navigate to: IAM → Dashboard → Security Status
# Enable MFA for root account (use hardware token or authenticator app)
```

**Validation:**
- [ ] Root account has MFA enabled
- [ ] MFA device tested and working
- [ ] Recovery codes saved securely

#### 1.2 Create Initial IAM Admin User

```bash
# Create admin user with programmatic and console access
aws iam create-user --user-name landing-zone-admin

# Create access key
aws iam create-access-key --user-name landing-zone-admin

# Attach AdministratorAccess policy (temporary, will be restricted later)
aws iam attach-user-policy \
  --user-name landing-zone-admin \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create console password
aws iam create-login-profile \
  --user-name landing-zone-admin \
  --password 'TempPassword123!' \
  --password-reset-required
```

**Security Note:** Store credentials in password manager immediately.

#### 1.3 Configure AWS CLI Profile

```bash
# Configure AWS CLI with admin user credentials
aws configure --profile landing-zone

# Test configuration
aws sts get-caller-identity --profile landing-zone

# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/landing-zone-admin"
# }
```

### Step 2: Initialize Terraform Backend

**Duration:** 15 minutes

#### 2.1 Create S3 Bucket for Terraform State

```bash
# Set variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile landing-zone)
export AWS_REGION="us-east-1"
export STATE_BUCKET="landing-zone-terraform-state-${AWS_ACCOUNT_ID}"

# Create S3 bucket
aws s3api create-bucket \
  --bucket ${STATE_BUCKET} \
  --region ${AWS_REGION} \
  --profile landing-zone

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${STATE_BUCKET} \
  --versioning-configuration Status=Enabled \
  --profile landing-zone

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${STATE_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --profile landing-zone

# Block public access
aws s3api put-public-access-block \
  --bucket ${STATE_BUCKET} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile landing-zone
```

#### 2.2 Create DynamoDB Table for State Locking

```bash
# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION} \
  --profile landing-zone

# Wait for table to be active
aws dynamodb wait table-exists \
  --table-name terraform-state-lock \
  --profile landing-zone

echo "Terraform backend ready!"
```

#### 2.3 Configure Terraform Backend

```bash
cd terraform/global

# Create backend configuration
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "${STATE_BUCKET}"
    key            = "landing-zone/global/terraform.tfstate"
    region         = "${AWS_REGION}"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
EOF

# Initialize Terraform
terraform init
```

**Validation:**
- [ ] S3 bucket created and encrypted
- [ ] DynamoDB table active
- [ ] Terraform initialized successfully

### Step 3: Enable AWS Organizations

**Duration:** 20 minutes

#### 3.1 Create Organization

```bash
# Enable AWS Organizations
aws organizations create-organization \
  --feature-set ALL \
  --profile landing-zone

# Verify organization creation
aws organizations describe-organization --profile landing-zone
```

#### 3.2 Enable AWS Service Access

```bash
# Enable service access for required services
for service in \
  cloudtrail.amazonaws.com \
  config.amazonaws.com \
  guardduty.amazonaws.com \
  securityhub.amazonaws.com \
  sso.amazonaws.com \
  controltower.amazonaws.com \
  backup.amazonaws.com
do
  aws organizations enable-aws-service-access \
    --service-principal $service \
    --profile landing-zone
  echo "Enabled: $service"
done
```

#### 3.3 Enable Policy Types

```bash
# Get root ID
ROOT_ID=$(aws organizations list-roots \
  --query 'Roots[0].Id' \
  --output text \
  --profile landing-zone)

# Enable policy types
aws organizations enable-policy-type \
  --root-id ${ROOT_ID} \
  --policy-type SERVICE_CONTROL_POLICY \
  --profile landing-zone

aws organizations enable-policy-type \
  --root-id ${ROOT_ID} \
  --policy-type TAG_POLICY \
  --profile landing-zone
```

**Validation:**
- [ ] Organization created with ALL features
- [ ] All required services enabled
- [ ] Policy types enabled

### Step 4: Deploy Core Infrastructure

**Duration:** 45 minutes

#### 4.1 Configure Terraform Variables

```bash
cd terraform/global

# Create terraform.tfvars
cat > terraform.tfvars << EOF
# Organization Configuration
organization_name = "YourCompany"
organization_domain = "yourcompany.com"

# AWS Configuration
aws_region = "us-east-1"
environment = "management"

# Security Features
enable_cloudtrail = true
enable_config = true
enable_guardduty = true
enable_security_hub = true
enable_access_analyzer = true

# Compliance Requirements
compliance_frameworks = ["sox", "pci-dss", "gdpr"]

# Network Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Tagging
cost_center = "infrastructure"
owner_email = "cloud-team@yourcompany.com"
EOF
```

#### 4.2 Review Terraform Plan

```bash
# Generate execution plan
terraform plan -out=phase1.tfplan

# Review plan carefully
# Expected resources: ~30-40 resources
# - AWS Organizations structure
# - Organizational Units (Security, Shared Services, Workloads)
# - Service Control Policies
# - Initial IAM roles
```

**Critical Review Points:**
- [ ] No unexpected deletions
- [ ] Resource counts reasonable
- [ ] Policy attachments correct
- [ ] Tags properly applied

#### 4.3 Apply Phase 1 Infrastructure

```bash
# Apply the plan
terraform apply phase1.tfplan

# This will take 10-15 minutes
# Monitor for any errors

# Verify deployment
terraform output
```

**Expected Outputs:**
```
organization_id = "o-xxxxxxxxxx"
organization_root_id = "r-xxxx"
organizational_units = {
  security = { id = "ou-xxxx-xxxxxxxx", ... }
  shared_services = { id = "ou-xxxx-xxxxxxxx", ... }
  workloads = { id = "ou-xxxx-xxxxxxxx", ... }
}
```

**Validation:**
- [ ] All resources created successfully
- [ ] No errors in Terraform output
- [ ] Organization structure visible in AWS Console
- [ ] SCPs applied to correct OUs

---

## Phase 2: Security Baseline

### Step 5: Deploy Security Services

**Duration:** 1 hour

#### 5.1 Deploy Security Account Baseline

```bash
cd terraform/modules/account-baseline

# Create tfvars for security account
cat > security-account.tfvars << EOF
account_name = "security-prod"
enable_guardduty = true
enable_security_hub = true
enable_config = true
enable_cloudtrail = true
enable_access_analyzer = true

# Use centralized buckets
config_s3_bucket_name = "org-central-config-bucket"
cloudtrail_s3_bucket_name = "org-central-cloudtrail-bucket"
EOF

# Plan and apply
terraform init
terraform plan -var-file=security-account.tfvars -out=security.tfplan
terraform apply security.tfplan
```

#### 5.2 Enable GuardDuty Organization

```bash
# Enable GuardDuty in master account
DETECTOR_ID=$(aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES \
  --query 'DetectorId' \
  --output text \
  --profile landing-zone)

echo "GuardDuty Detector ID: ${DETECTOR_ID}"

# Enable S3 protection
aws guardduty update-detector \
  --detector-id ${DETECTOR_ID} \
  --data-sources '{"S3Logs":{"Enable":true}}' \
  --profile landing-zone
```

#### 5.3 Enable Security Hub

```bash
# Enable Security Hub
aws securityhub enable-security-hub \
  --enable-default-standards \
  --profile landing-zone

# Enable standards
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    'StandardsArn=arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0' \
    'StandardsArn=arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/1.4.0' \
  --profile landing-zone
```

**Validation:**
- [ ] GuardDuty enabled and running
- [ ] Security Hub enabled with standards
- [ ] Config rules deployed
- [ ] CloudTrail logging to S3

### Step 6: Deploy Centralized Logging

**Duration:** 30 minutes

```bash
cd terraform/modules/logging

# Configure logging module
terraform init
terraform plan -out=logging.tfplan
terraform apply logging.tfplan

# Verify log groups created
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/organization/" \
  --profile landing-zone
```

**Validation:**
- [ ] Centralized S3 bucket created
- [ ] CloudWatch log groups created
- [ ] Metric filters configured
- [ ] SNS topics for alerts created

---

## Phase 3: Network Infrastructure

### Step 7: Deploy Transit Gateway

**Duration:** 45 minutes

#### 7.1 Create Transit Gateway

```bash
cd terraform/modules/networking

# Deploy Transit Gateway
terraform init
terraform plan -var="enable_transit_gateway=true" -out=tgw.tfplan
terraform apply tgw.tfplan

# Get Transit Gateway ID
TGW_ID=$(terraform output -raw transit_gateway_id)
echo "Transit Gateway ID: ${TGW_ID}"
```

#### 7.2 Configure Route Tables

```bash
# Transit Gateway route tables are created automatically
# Verify creation
aws ec2 describe-transit-gateway-route-tables \
  --filters "Name=transit-gateway-id,Values=${TGW_ID}" \
  --profile landing-zone
```

### Step 8: Deploy VPCs

**Duration:** 1 hour

#### 8.1 Deploy Shared Services VPC

```bash
cd terraform/environments/shared-services

# Create VPC configuration
cat > shared-services.tfvars << EOF
vpc_name = "shared-services-vpc"
vpc_cidr = "10.0.0.0/16"
environment = "production"

enable_public_subnets = true
enable_nat_gateway = true
single_nat_gateway = false  # Multi-AZ for HA

transit_gateway_id = "${TGW_ID}"
EOF

# Deploy
terraform init
terraform plan -var-file=shared-services.tfvars -out=shared-vpc.tfplan
terraform apply shared-vpc.tfplan
```

#### 8.2 Deploy Workload VPCs

```bash
cd terraform/environments/workloads

# Production VPC
cat > production.tfvars << EOF
vpc_name = "production-vpc"
vpc_cidr = "10.1.0.0/16"
environment = "production"

enable_database_subnets = true
enable_nat_gateway = true
single_nat_gateway = false

transit_gateway_id = "${TGW_ID}"
EOF

terraform init
terraform plan -var-file=production.tfvars -out=prod-vpc.tfplan
terraform apply prod-vpc.tfplan
```

**Validation:**
- [ ] Transit Gateway created and available
- [ ] VPCs created in correct OUs
- [ ] Subnets properly distributed across AZs
- [ ] NAT Gateways deployed
- [ ] Transit Gateway attachments successful
- [ ] Route tables configured correctly

---

## Phase 4: Testing and Validation

### Step 9: Comprehensive Testing

**Duration:** 1-2 hours

#### 9.1 Security Testing

```bash
# Test SCP enforcement
aws ec2 run-instances \
  --image-id ami-12345678 \
  --instance-type p3.16xlarge \
  --profile workload-dev

# Expected: AccessDenied due to instance type restriction

# Test encryption enforcement
aws s3 cp test.txt s3://test-bucket/test.txt
# Expected: AccessDenied due to missing encryption
```

#### 9.2 Network Connectivity Testing

```bash
# Test connectivity between VPCs through Transit Gateway
# Launch test instances in different VPCs
# Verify ping/SSH connectivity

# Test NAT Gateway egress
# From private subnet instance, test internet connectivity
curl -I https://www.google.com
```

#### 9.3 Compliance Validation

```bash
# Check Config compliance
aws configservice describe-compliance-by-config-rule \
  --profile landing-zone

# Check Security Hub score
aws securityhub get-findings-summary \
  --group-by-attribute SEVERITY \
  --profile landing-zone

# Expected: >95% compliance score
```

### Step 10: Documentation and Handoff

**Duration:** 2 hours

#### 10.1 Generate Documentation

```bash
# Generate Terraform documentation
terraform-docs markdown table . > TERRAFORM.md

# Export network diagram
# Take screenshots of:
# - Organization structure
# - Transit Gateway topology
# - Security Hub dashboard
# - Cost Explorer dashboard
```

#### 10.2 Create Operations Handoff

Create document with:
- [ ] All account IDs and purposes
- [ ] Access procedures (SSO, emergency access)
- [ ] Monitoring dashboard URLs
- [ ] Escalation procedures
- [ ] Cost baseline and budgets
- [ ] Scheduled maintenance windows

---

## Post-Deployment Tasks

### Immediate (Day 1)

- [ ] Verify all monitoring and alerting working
- [ ] Test incident response procedures
- [ ] Validate backup jobs running
- [ ] Configure cost alerts
- [ ] Schedule first DR test

### Week 1

- [ ] Train operations team on runbooks
- [ ] Conduct tabletop exercise
- [ ] Review and optimize costs
- [ ] Fine-tune alerting thresholds
- [ ] Document lessons learned

### Month 1

- [ ] First disaster recovery test
- [ ] Compliance audit
- [ ] Cost optimization review
- [ ] Security posture assessment
- [ ] Update procedures based on findings

---

## Rollback Procedures

### If Deployment Fails

```bash
# Phase 1-2 Rollback
cd terraform/global
terraform destroy -auto-approve

# Phase 3 Rollback (Network)
cd terraform/modules/networking
terraform destroy -target=aws_ec2_transit_gateway.main

# Cleanup manually if needed
aws organizations delete-organization --profile landing-zone
```

### Partial Rollback

```bash
# Destroy specific resources
terraform destroy -target=aws_guardduty_detector.main

# Remove specific accounts
terraform destroy -target=aws_organizations_account.workload-dev-1
```

---

## Troubleshooting

See [Troubleshooting Guide](troubleshooting.md) for common issues and solutions.

## Support

- **Documentation:** [Project Wiki](../../README.md)
- **Issues:** GitHub Issues
- **AWS Support:** Enterprise Support Console

---

**Last Updated:** September 2025  
**Version:** 1.0  
**Maintained By:** Cloud Infrastructure Team
