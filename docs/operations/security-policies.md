# Security Policies and Service Control Policies (SCPs)

## Overview

This document describes the Service Control Policies (SCPs) implemented in the AWS Enterprise Landing Zone. These policies enforce security, compliance, and cost control guardrails across all accounts in the organization.

## Policy Hierarchy

```
Organization Root
├── Security Baseline (Applied to Root)
├── Cost Control (Applied to Non-Production OUs)
└── Compliance Guardrails (Applied to Production OUs)
```

## Security Baseline Policy

**Purpose:** Enforce fundamental security controls across all accounts  
**Scope:** Applied to the Organization Root (affects all accounts)  
**Policy File:** `policies/service-control-policies/security-baseline.json`

### Key Controls

#### 1. Root Account Protection
- **Control:** Deny all actions by root account
- **Rationale:** Root account should only be used for emergency access
- **Impact:** Root account cannot perform any API operations
- **Override:** Manual intervention required in AWS Console

#### 2. Security Services Protection
Prevents disabling or modification of critical security services:
- AWS GuardDuty
- AWS Config
- AWS CloudTrail
- AWS Security Hub
- IAM Access Analyzer

**Rationale:** Ensures continuous security monitoring and compliance tracking

#### 3. Critical IAM Role Protection
Prevents modification or deletion of:
- `OrganizationAccountAccessRole`
- `AWSControlTowerExecution`
- `AWSConfigRole`
- `AWSCloudTrailLogsRole`
- Roles containing `SecurityAudit` or `Backup`

**Rationale:** Protects roles essential for organization governance and security operations

#### 4. Encryption Enforcement

##### S3 Encryption
- **Control:** Deny S3 PutObject without server-side encryption
- **Allowed encryption:** AES256 or aws:kms
- **Impact:** All S3 uploads must be encrypted

##### EBS Encryption
- **Control:** Deny EC2 instance launch with unencrypted volumes
- **Impact:** All EBS volumes must be encrypted at creation

##### RDS Encryption
- **Control:** Deny creation of unencrypted RDS instances/clusters
- **Impact:** All RDS databases must have encryption at rest enabled

#### 5. Public Access Prevention

##### S3 Buckets
- **Control:** Prevent disabling S3 public access block settings
- **Impact:** S3 buckets cannot be made public

##### RDS Instances
- **Control:** Deny public accessibility for RDS instances
- **Impact:** RDS instances cannot be publicly accessible

#### 6. MFA Requirement for Sensitive Operations
- **Control:** Require MFA for destructive operations
- **Protected actions:**
  - IAM user/role deletion
  - EC2 instance termination
  - RDS instance deletion
  - S3 bucket deletion
- **Impact:** Users must have active MFA session for these operations

### Implementation Example

```bash
# Apply security baseline to root
aws organizations attach-policy \
  --policy-id p-xxxxxxxx \
  --target-id r-xxxx
```

### Testing Security Controls

```bash
# Test 1: Attempt to disable GuardDuty (should fail)
aws guardduty delete-detector --detector-id xxxxx
# Expected: AccessDenied with SCP violation

# Test 2: Attempt to upload unencrypted object to S3 (should fail)
aws s3 cp file.txt s3://bucket/ 
# Expected: AccessDenied due to missing encryption

# Test 3: Attempt to create unencrypted EBS volume (should fail)
aws ec2 run-instances --image-id ami-xxxxx --instance-type t3.micro \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=10,Encrypted=false}"
# Expected: UnauthorizedOperation
```

## Cost Control Policy

**Purpose:** Prevent unexpected costs and enforce spending limits  
**Scope:** Applied to Development and Staging OUs  
**Policy File:** `policies/service-control-policies/cost-control.json`

### Key Controls

#### 1. Region Restrictions
- **Allowed regions:** us-east-1, us-west-2, eu-west-1
- **Exempted services:** IAM, Organizations, Route 53, CloudFront, Support
- **Rationale:** Concentrate resources in approved regions to reduce data transfer costs

#### 2. Instance Type Restrictions

##### EC2 Instances
**Denied instance types:**
- Metal instances (*.metal)
- Extra-large instances (16xlarge, 24xlarge, 32xlarge)
- GPU instances (p3.*, p4.*, g4dn.*)
- Memory-optimized (x1.*, x2.*, z1d.*)

**Rationale:** Prevent accidental launch of expensive instances in non-production

##### RDS Instances
**Denied database classes:**
- Extra-large instances (16xlarge+)
- Memory-optimized (x1.*, x2.*)

#### 3. Resource Tagging Requirements
- **Control:** Deny resource creation without required tags
- **Required tags:**
  - CostCenter
  - Owner
  - Environment
- **Impact:** All billable resources must have cost allocation tags

#### 4. EBS Volume Size Limits
- **Control:** Deny volumes larger than 1TB
- **Rationale:** Prevent accidentally large storage provisioning
- **Override:** Request approval for larger volumes

#### 5. Budget Protection
- **Control:** Prevent deletion or modification of budget alerts
- **Rationale:** Ensure cost monitoring remains active

### Cost Savings Impact

| Control | Estimated Monthly Savings |
|---------|--------------------------|
| Region restrictions | $150-300 (data transfer) |
| Instance type limits | $500-1000 (oversized instances) |
| Volume size limits | $100-200 (unused storage) |
| Tag enforcement | 15-20% (better cost allocation) |

## Compliance Guardrails Policy

**Purpose:** Enforce regulatory compliance requirements  
**Scope:** Applied to Production OU  
**Policy File:** `policies/service-control-policies/compliance-guardrails.json`

### Key Controls

#### 1. Data Residency (GDPR Compliance)
- **Control:** Restrict PII data to EU regions
- **Mechanism:** Tag-based enforcement (`DataClassification: PII`)
- **Allowed regions:** eu-west-1, eu-central-1
- **Impact:** Resources with PII tags can only be created in EU

#### 2. Encryption Requirements

##### At Rest
- **Enforced for:** S3, DynamoDB, Kinesis, SQS
- **Allowed encryption:** AES256 or AWS KMS
- **Compliance:** PCI-DSS, HIPAA, SOX

##### In Transit
- **Control:** Require HTTPS/TLS for all data transfers
- **Enforced for:** S3, Load Balancers, API Gateway
- **Compliance:** PCI-DSS Requirement 4.1

#### 3. Backup Retention (SOX Compliance)
- **Control:** Enforce minimum 7-year retention for backups
- **Retention period:** 2555 days
- **Protected:** Recovery points cannot be deleted before retention period
- **Compliance:** Sarbanes-Oxley Act

#### 4. VPC Endpoint Requirements
- **Control:** Sensitive data access must use VPC endpoints
- **Applies to:** Resources tagged as Confidential or Restricted
- **Services:** S3, DynamoDB, SQS
- **Rationale:** Prevent data exfiltration via public internet

#### 5. Public Sharing Prevention
**Denied actions:**
- Public AMI sharing
- Public EBS snapshot sharing
- Public RDS snapshot sharing

**Rationale:** Prevent accidental data exposure

#### 6. Audit Trail Protection
- **Control:** CloudTrail cannot be disabled in audit accounts
- **Protected operations:**
  - Delete trail
  - Stop logging
  - Modify event selectors
- **Compliance:** All regulatory frameworks require audit logging

#### 7. Production Change Controls
- **Control:** Production resource deletion requires senior approval
- **Mechanism:** Principal tag `ChangeApprovalLevel: Senior`
- **Protected resources:** EC2, RDS, S3, Lambda in production
- **Process:** Change management workflow integration

### Compliance Mapping

| Framework | Controls Covered | Evidence |
|-----------|------------------|----------|
| **SOC 2** | CC6.1, CC6.6, CC7.2 | Encryption, access controls, monitoring |
| **PCI DSS** | 3.4, 4.1, 8.2, 10.1 | Encryption, network security, logging |
| **GDPR** | Art. 32, Art. 33 | Data residency, encryption, breach detection |
| **HIPAA** | 164.308, 164.312 | Access controls, encryption, audit logs |
| **SOX** | Section 404 | Data retention, change management |

## Policy Exemptions

### Emergency Access Procedure

For legitimate business needs requiring policy exemption:

1. **Submit exemption request** with business justification
2. **Approval required** from Security and Compliance teams
3. **Temporary exemption** granted (max 30 days)
4. **Audit trail** maintained in ticketing system

### Exemption Process

```bash
# Create temporary exemption (requires elevated privileges)
aws organizations detach-policy \
  --policy-id p-xxxxxxxx \
  --target-id ou-xxxx-xxxxxxxx

# Document in compliance system
# Schedule automatic re-attachment after 30 days
```

## Monitoring and Alerting

### SCP Violation Detection

CloudWatch metric filters track SCP violations:

```json
{
  "filterPattern": "{ $.errorCode = \"AccessDenied\" && $.errorMessage = \"*organizational policy*\" }",
  "metricTransformation": {
    "metricName": "SCPViolations",
    "metricNamespace": "Security/Compliance"
  }
}
```

### Alert Thresholds

- **Info:** 1-5 violations/hour (user education needed)
- **Warning:** 6-20 violations/hour (investigate patterns)
- **Critical:** 20+ violations/hour (potential attack or misconfiguration)

## Best Practices

### 1. Least Privilege Access
- Grant minimum permissions needed
- Use temporary credentials
- Implement just-in-time access

### 2. Regular Policy Reviews
- **Quarterly:** Review policy effectiveness
- **Annually:** Update based on new compliance requirements
- **Ad-hoc:** After security incidents or major changes

### 3. Testing Before Production
- Test all SCPs in sandbox account first
- Validate with application teams
- Document expected impacts

### 4. Communication Strategy
- Announce policy changes 2 weeks in advance
- Provide migration guides for affected teams
- Offer office hours for questions

### 5. Documentation
- Maintain policy rationale documentation
- Update runbooks with SCP considerations
- Track exemptions and their expiration

## Troubleshooting

### Common Issues

#### Issue: Legitimate action blocked by SCP

**Symptoms:**
```
AccessDenied: You are not authorized to perform this operation
```

**Resolution:**
1. Check CloudTrail for exact denied action
2. Review applicable SCPs
3. Verify if exemption is warranted
4. Submit exemption request if needed

#### Issue: Root account truly needed

**Process:**
1. Verify no alternative exists
2. Obtain approval from CISO
3. Temporarily detach SCP from root
4. Perform action with full audit trail
5. Re-attach SCP immediately

#### Issue: New service blocked by region restriction

**Resolution:**
1. Evaluate if service is truly needed
2. If yes, update Cost Control SCP to exempt service
3. Document business justification
4. Deploy updated policy

## Related Documentation

- [Security Architecture](../architecture/security-model.md)
- [Incident Response Procedures](incident-response.md)
- [Compliance Reporting](compliance-reporting.md)
- [Change Management Process](change-management.md)

---

**Last Updated:** September 2025  
**Owner:** Security Team  
**Review Schedule:** Quarterly  
**Next Review:** December 2025
