# Deployment Troubleshooting Guide

## Overview

This guide provides solutions for common issues encountered during AWS Enterprise Landing Zone deployment. Issues are organized by deployment phase and severity.

---

## General Troubleshooting

### Enable Terraform Debug Logging

```bash
# Enable detailed Terraform logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# Run Terraform command
terraform apply

# Review logs
cat terraform-debug.log
```

### Verify AWS Credentials

```bash
# Check current identity
aws sts get-caller-identity

# Verify assumed role (if using roles)
aws sts get-session-token

# Test API access
aws ec2 describe-regions --output table
```

---

## Phase 1: Foundation Setup Issues

### Issue: Cannot Create AWS Organization

**Error Message:**
```
Error: Error creating organization: ConstraintViolationException: 
This account is already a member of an organization
```

**Cause:** Account is already part of an organization

**Solution:**
```bash
# Check current organization
aws organizations describe-organization

# If part of unwanted organization, leave it
aws organizations leave-organization

# Wait 30 seconds, then retry
terraform apply
```

**Prevention:** Always start with fresh account or properly leave existing organization.

---

### Issue: Service Control Policy Attachment Fails

**Error Message:**
```
Error: error attaching policy to target: DuplicatePolicyAttachmentException
```

**Cause:** Policy already attached or conflicting attachment

**Solution:**
```bash
# List attached policies
aws organizations list-policies-for-target \
  --target-id ou-xxxx-xxxxxxxx \
  --filter SERVICE_CONTROL_POLICY

# Detach if needed
aws organizations detach-policy \
  --policy-id p-xxxxxxxx \
  --target-id ou-xxxx-xxxxxxxx

# Retry Terraform
terraform apply
```

---

### Issue: Terraform State Lock

**Error Message:**
```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx
  Path: landing-zone/terraform.tfstate
```

**Cause:** Previous Terraform operation didn't complete cleanly

**Solution:**
```bash
# Force unlock (ONLY if you're sure no other Terraform is running)
terraform force-unlock xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx

# Check DynamoDB for stuck locks
aws dynamodb scan \
  --table-name terraform-state-lock \
  --profile landing-zone

# If needed, manually delete lock item from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "landing-zone-terraform-state-lock"}}' \
  --profile landing-zone
```

**Prevention:** Always let Terraform complete or Ctrl+C cleanly.

---

## Phase 2: Security Services Issues

### Issue: GuardDuty Already Enabled

**Error Message:**
```
Error: error creating GuardDuty Detector: 
BadRequestException: The request is rejected because the current account has already been enabled
```

**Cause:** GuardDuty was previously enabled or Control Tower enabled it

**Solution:**
```bash
# Import existing detector into Terraform state
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
terraform import aws_guardduty_detector.main ${DETECTOR_ID}

# Rerun apply
terraform apply
```

---

### Issue: Config Recorder Already Running

**Error Message:**
```
Error: error creating Configuration Recorder: 
MaxNumberOfConfigurationRecordersExceededException: Only 1 configuration recorder allowed
```

**Cause:** Config recorder already exists (AWS allows only one per region)

**Solution:**
```bash
# Check existing recorders
aws configservice describe-configuration-recorders

# Option 1: Import existing
terraform import aws_config_configuration_recorder.main default

# Option 2: Delete existing and recreate
aws configservice stop-configuration-recorder \
  --configuration-recorder-name default
aws configservice delete-configuration-recorder \
  --configuration-recorder-name default

# Retry
terraform apply
```

---

### Issue: S3 Bucket Already Exists

**Error Message:**
```
Error: error creating S3 bucket: BucketAlreadyExists: 
The requested bucket name is not available
```

**Cause:** S3 bucket names are globally unique

**Solution:**
```bash
# Add account ID to bucket name
export TF_VAR_centralized_logging_bucket_name="org-logs-${AWS_ACCOUNT_ID}"

# Or use random suffix
export TF_VAR_centralized_logging_bucket_name="org-logs-$(uuidgen | cut -c1-8)"

# Retry
terraform apply
```

---

### Issue: CloudTrail Multi-Region Trail Conflict

**Error Message:**
```
Error: error creating CloudTrail: TrailAlreadyExistsException
```

**Cause:** Multi-region trail already exists

**Solution:**
```bash
# List existing trails
aws cloudtrail describe-trails

# Import existing trail
TRAIL_ARN=$(aws cloudtrail describe-trails --query 'trailList[0].TrailARN' --output text)
terraform import aws_cloudtrail.main ${TRAIL_ARN}

# Or delete and recreate
aws cloudtrail delete-trail --name existing-trail-name
terraform apply
```

---

## Phase 3: Network Infrastructure Issues

### Issue: CIDR Block Conflicts

**Error Message:**
```
Error: error creating VPC: InvalidVpcRange: 
The CIDR '10.0.0.0/16' conflicts with another VPC
```

**Cause:** Overlapping CIDR blocks

**Solution:**
1. Review IP address allocation plan
2. Use non-overlapping CIDRs:
   ```
   Management:     10.0.0.0/16
   Security:       10.1.0.0/16
   Shared Svc:     10.2.0.0/16
   Workloads:      10.10.0.0/16, 10.11.0.0/16, ...
   ```
3. Update terraform.tfvars
4. Retry deployment

---

### Issue: Transit Gateway Attachment Timeout

**Error Message:**
```
Error: error waiting for EC2 Transit Gateway VPC Attachment to become available: 
timeout while waiting for state to become 'available'
```

**Cause:** Network connectivity issues or subnet configuration problems

**Solution:**
```bash
# Check attachment status
aws ec2 describe-transit-gateway-vpc-attachments \
  --filters "Name=state,Values=pending,failed"

# Check subnet configuration
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxx"

# If failed, delete and recreate
aws ec2 delete-transit-gateway-vpc-attachment \
  --transit-gateway-attachment-id tgw-attach-xxxxxxxx

# Wait 5 minutes, then retry Terraform
terraform apply
```

---

### Issue: NAT Gateway Creation Fails

**Error Message:**
```
Error: error creating NAT Gateway: 
InvalidAllocationID.NotFound: The allocation ID 'eipalloc-xxxxx' does not exist
```

**Cause:** EIP allocation timing issue

**Solution:**
```bash
# Add explicit depends_on in Terraform
resource "aws_nat_gateway" "main" {
  # ...
  depends_on = [aws_eip.nat]
}

# Or use targeted apply
terraform apply -target=aws_eip.nat
sleep 30
terraform apply
```

---

### Issue: Subnet CIDR Exhaustion

**Error Message:**
```
Error: error creating subnet: InvalidSubnet.Range: 
The CIDR '10.0.1.0/24' is invalid for a VPC with CIDR '10.0.0.0/24'
```

**Cause:** Subnet CIDR doesn't fit in VPC CIDR

**Solution:**
- Verify VPC has sufficient address space (/16 recommended)
- Calculate subnets properly:
  ```
  VPC: 10.0.0.0/16 (65,536 IPs)
  Public:  10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
  Private: 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
  DB:      10.0.20.0/24, 10.0.21.0/24, 10.0.22.0/24
  ```

---

## Permission and IAM Issues

### Issue: Insufficient Permissions

**Error Message:**
```
Error: error creating resource: AccessDeniedException: 
User: arn:aws:iam::123456789012:user/deployer is not authorized to perform: ACTION
```

**Cause:** IAM user/role lacks necessary permissions

**Solution:**
```bash
# Verify current permissions
aws iam get-user-policy \
  --user-name deployer \
  --policy-name deployment-policy

# Attach necessary policy (temporarily use AdministratorAccess for deployment)
aws iam attach-user-policy \
  --user-name deployer \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# After deployment, reduce to least-privilege
```

**Best Practice:** Use dedicated deployment role with only required permissions.

---

### Issue: Role Assumption Failure

**Error Message:**
```
Error: error assuming role: AccessDenied: 
User is not authorized to perform: sts:AssumeRole on resource
```

**Cause:** Trust relationship not configured correctly

**Solution:**
```bash
# Check trust policy
aws iam get-role --role-name DeploymentRole --query 'Role.AssumeRolePolicyDocument'

# Update trust policy if needed
aws iam update-assume-role-policy \
  --role-name DeploymentRole \
  --policy-document file://trust-policy.json
```

---

## Terraform-Specific Issues

### Issue: Resource Already Exists (Not in State)

**Error Message:**
```
Error: resource already exists
```

**Cause:** Resource created outside Terraform or state file out of sync

**Solution:**
```bash
# Import resource into state
terraform import <resource_type>.<resource_name> <resource_id>

# Example: Import VPC
terraform import aws_vpc.main vpc-0123456789abcdef0

# Verify state
terraform state list
terraform state show aws_vpc.main
```

---

### Issue: Drift Detection

**Problem:** Terraform plan shows unexpected changes

**Cause:** Resources modified outside Terraform

**Solution:**
```bash
# Check for drift
terraform plan -refresh-only

# Review specific resource
terraform state show aws_vpc.main

# Options:
# 1. Accept drift (update Terraform to match)
terraform apply -refresh-only

# 2. Revert manual changes to match Terraform
# (Manually revert in AWS Console or AWS CLI)

# 3. Remove from state if no longer needed
terraform state rm aws_vpc.main
```

---

## Cost and Billing Issues

### Issue: Unexpected Costs

**Problem:** AWS bill higher than expected

**Investigation:**
```bash
# Check daily costs
aws ce get-cost-and-usage \
  --time-period Start=2025-09-25,End=2025-09-30 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Identify cost anomalies
aws ce get-anomalies \
  --date-interval Start=2025-09-25 \
  --max-results 10

# Check for unexpected resources
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]'
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass]'
```

**Common causes:**
- NAT Gateway data processing fees
- Inter-region data transfer
- GuardDuty/Config charges higher than estimated
- Forgotten test resources

---

## Connectivity and Network Issues

### Issue: Cannot Connect to Instances

**Problem:** SSH/RDP connection failures

**Troubleshooting steps:**
```bash
# 1. Verify instance running
aws ec2 describe-instances --instance-ids i-xxxxxxxx

# 2. Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxx

# 3. Verify route tables
aws ec2 describe-route-tables --route-table-ids rtb-xxxxxxxx

# 4. Check NACLs
aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=subnet-xxxxxxxx"

# 5. Test connectivity
aws ec2-instance-connect send-ssh-public-key \
  --instance-id i-xxxxxxxx \
  --instance-os-user ec2-user \
  --ssh-public-key file://~/.ssh/id_rsa.pub
```

---

## Performance Issues

### Issue: Slow Terraform Apply

**Problem:** Terraform taking too long

**Optimization:**
```bash
# Use parallelism (default is 10)
terraform apply -parallelism=20

# Target specific resources
terraform apply -target=module.networking

# Use refresh=false if state is current
terraform apply -refresh=false

# Upgrade Terraform version
terraform version
```

---

## Recovery Procedures

### Complete Deployment Failure

**If deployment completely fails:**

1. **Save state file:**
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   aws s3 cp terraform.tfstate s3://backup-bucket/
   ```

2. **Document current state:**
   ```bash
   terraform state list > deployed-resources.txt
   ```

3. **Attempt targeted destroy:**
   ```bash
   terraform destroy -target=module.networking
   terraform destroy -target=module.security
   ```

4. **If destroy fails, manual cleanup:**
   ```bash
   # Delete VPCs
   # Delete Transit Gateway
   # Delete S3 buckets
   # Leave organization (if needed)
   ```

---

## Getting Help

### Collect Information

Before requesting help, gather:

```bash
# Terraform version
terraform version > debug-info.txt

# AWS CLI version
aws --version >> debug-info.txt

# Account information
aws sts get-caller-identity >> debug-info.txt

# Error message (sanitize sensitive data!)
# Terraform plan output
# CloudTrail events for failed operations
```

### AWS Support

```bash
# Create support case (Enterprise Support required)
aws support create-case \
  --subject "Landing Zone Deployment Issue" \
  --service-code "general-info" \
  --severity-code "high" \
  --category-code "other" \
  --communication-body "Detailed description..." \
  --cc-email-addresses "team@company.com"
```

### Community Resources

- AWS re:Post: https://repost.aws/
- Terraform Registry Issues
- GitHub Issues (for this project)

---

## Prevention Best Practices

### Before Each Deployment

- [ ] Test in sandbox account first
- [ ] Review Terraform plan carefully
- [ ] Backup state file
- [ ] Document current state
- [ ] Have rollback plan ready
- [ ] Schedule adequate time window
- [ ] Notify stakeholders

### During Deployment

- [ ] Monitor CloudTrail for errors
- [ ] Watch AWS Console for resource creation
- [ ] Keep terminal logs
- [ ] Note any warnings or errors immediately

### After Deployment

- [ ] Validate all resources created
- [ ] Test connectivity
- [ ] Verify monitoring and alerting
- [ ] Document any issues encountered
- [ ] Update troubleshooting guide

---

**Last Updated:** September 2025  
**Keep This Document Handy During Deployment**
