# Prerequisites Checklist

## Overview

Before deploying the AWS Enterprise Landing Zone, ensure all prerequisites are met. This checklist helps prevent deployment issues and ensures smooth implementation.

**Estimated Time to Complete Checklist:** 2-3 hours

---

## AWS Account Requirements

### Management Account

- [ ] **AWS Account created** and accessible
- [ ] **Root email address** documented and accessible
- [ ] **Account not part of existing organization** (or able to leave current organization)
- [ ] **Billing information** configured and valid payment method attached
- [ ] **Service limits** reviewed (especially Organizations, VPC, EC2)
- [ ] **Support plan** upgraded to Business or Enterprise (recommended)

**Verification:**
```bash
aws sts get-caller-identity
aws organizations describe-organization 2>&1 | grep -q "AWSOrganizationsNotInUseException" && echo "Ready for Organizations" || echo "Already in organization"
```

### Account Naming Convention

Document your account naming strategy:

```
Format: <environment>-<function>-<region/number>

Examples:
- management-org
- security-prod
- shared-services-prod
- workload-prod-webapp
- workload-staging-api
- workload-dev-sandbox
```

---

## Access and Credentials

### AWS CLI

- [ ] **AWS CLI v2** installed (minimum version 2.13.0)
- [ ] **Credentials configured** with AdministratorAccess (temporary)
- [ ] **Named profile** created (e.g., `landing-zone`)
- [ ] **MFA enabled** on IAM user/role
- [ ] **Session token** configured for MFA if required

**Verification:**
```bash
# Check AWS CLI version
aws --version
# Expected: aws-cli/2.13.0 or higher

# Test credentials
aws sts get-caller-identity --profile landing-zone

# Test permissions
aws organizations describe-organization --profile landing-zone 2>&1
```

### Root Account Security

- [ ] **MFA enabled** on root account (hardware token recommended)
- [ ] **Root password** strong and stored in secure password manager
- [ ] **Root email** accessible (may need verification codes)
- [ ] **Alternative contacts** configured (billing, operations, security)
- [ ] **Security questions** set and answers documented securely

**Critical:** Root account should only be used for initial setup and emergency access.

---

## Software Requirements

### Local Development Environment

- [ ] **Operating System:** Linux, macOS, or WSL2 on Windows
- [ ] **Terraform** >= 1.5.0 installed
- [ ] **Python** 3.9+ with pip
- [ ] **Git** >= 2.30 installed
- [ ] **jq** (JSON processor) installed
- [ ] **Text editor** (VS Code, vim, etc.)

**Installation Commands:**

```bash
# Terraform
wget https://releases.hashicorp.com/terraform/1.6.2/terraform_1.6.2_linux_amd64.zip
unzip terraform_1.6.2_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Python dependencies
pip3 install boto3 click tabulate

# jq
sudo apt-get install jq  # Debian/Ubuntu
brew install jq          # macOS

# Verify installations
terraform version
python3 --version
git --version
jq --version
```

### Terraform Plugins

- [ ] **AWS Provider** ~> 5.0 (auto-installed by Terraform)
- [ ] **Random Provider** ~> 3.1 (auto-installed)
- [ ] **Local Provider** ~> 2.1 (auto-installed)

### Security Scanning Tools (Optional but Recommended)

- [ ] **tfsec** - Terraform security scanner
- [ ] **checkov** - Infrastructure as Code scanner
- [ ] **terraform-docs** - Documentation generator

```bash
# Install tfsec
brew install tfsec
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Install checkov
pip3 install checkov

# Install terraform-docs
brew install terraform-docs
```

---

## Network and Domain Requirements

### DNS Configuration

- [ ] **Domain registered** for organization (e.g., yourcompany.com)
- [ ] **Email addresses** available for new accounts:
  - `aws-security@yourcompany.com`
  - `aws-shared-services@yourcompany.com`
  - `aws-workload-prod@yourcompany.com`
  - etc.
- [ ] **Email forwarding** configured if using aliases
- [ ] **Email access** verified (can receive AWS verification emails)

**Important:** Each AWS account requires a unique email address. Consider using email aliases or a catch-all domain.

### IP Address Planning

- [ ] **CIDR blocks allocated** for VPCs (non-overlapping)
- [ ] **IP address plan** documented

**Recommended CIDR allocation:**
```
Management:        10.0.0.0/16
Security:          10.1.0.0/16
Shared Services:   10.2.0.0/16
Production-1:      10.10.0.0/16
Production-2:      10.11.0.0/16
Staging-1:         10.20.0.0/16
Staging-2:         10.21.0.0/16
Development-1:     10.30.0.0/16
Development-2:     10.31.0.0/16
```

### Connectivity Requirements

- [ ] **On-premises network ranges** documented (for VPN/Direct Connect)
- [ ] **Internet egress strategy** defined (NAT Gateway vs. proxy)
- [ ] **Allowed regions** identified (for compliance/data residency)

---

## Compliance and Security

### Regulatory Requirements

- [ ] **Compliance frameworks** identified (SOC2, PCI-DSS, GDPR, HIPAA, etc.)
- [ ] **Data residency** requirements documented
- [ ] **Retention policies** defined for logs and backups
- [ ] **Encryption requirements** documented

### Security Contacts

- [ ] **Security team contact** information
- [ ] **Incident response team** identified
- [ ] **On-call rotation** established (if applicable)
- [ ] **AWS Security Hub** notification emails configured

### Documentation

- [ ] **Security policies** approved
- [ ] **Acceptable use policy** defined
- [ ] **Change management process** established
- [ ] **Disaster recovery plan** drafted

---

## Financial and Budgeting

### Cost Planning

- [ ] **Monthly budget** approved
- [ ] **Cost allocation tags** strategy defined
- [ ] **Billing alerts** thresholds determined
- [ ] **Reserved Instance** strategy planned

**Expected Costs:**
- Small organization (5 accounts): ~$600/month
- Medium organization (15 accounts): ~$1,300/month
- Enterprise (50 accounts): ~$3,500/month

See [Cost Analysis](../../README.md#cost-analysis) for detailed breakdown.

### Billing Configuration

- [ ] **Consolidated billing** understood
- [ ] **Cost allocation tags** enabled in billing preferences
- [ ] **Cost and Usage Reports** location decided
- [ ] **Budget alerts** email recipients identified

---

## Organizational Readiness

### Team and Roles

- [ ] **Project sponsor** identified
- [ ] **Technical lead** assigned
- [ ] **Operations team** briefed
- [ ] **Training plan** for operations team created

### Communication Plan

- [ ] **Stakeholder list** documented
- [ ] **Communication channels** established (Slack, email lists)
- [ ] **Status reporting** schedule defined
- [ ] **Escalation procedures** documented

### Change Management

- [ ] **Deployment window** scheduled
- [ ] **Rollback plan** reviewed
- [ ] **Communication templates** prepared
- [ ] **Post-deployment validation** checklist ready

---

## Testing Environment

### Sandbox Account (Recommended)

- [ ] **Separate AWS account** for testing
- [ ] **Not production** - can be safely destroyed
- [ ] **Test deployment** completed successfully
- [ ] **Issues documented** and resolved

**Why test first?**
- Validate Terraform configurations
- Test Service Control Policies
- Train team on procedures
- Identify potential issues before production

---

## Service Limits

### Check AWS Service Quotas

```bash
# VPC limits
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --region us-east-1

# EC2 limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-east-1

# Organizations limits
aws organizations describe-organization
```

### Common Limits to Review

- [ ] **VPCs per region:** Default 5 (request increase to 20+)
- [ ] **Elastic IPs:** Default 5 (request based on NAT Gateway needs)
- [ ] **Internet Gateways:** Default 5 per region
- [ ] **Transit Gateway attachments:** Default 5,000 (usually sufficient)
- [ ] **Accounts in organization:** Default 10 (request increase as needed)
- [ ] **EC2 instances:** Review On-Demand and Spot limits

**Request increases early** - can take 24-48 hours for approval.

---

## Backup and Recovery

### Data Protection Plan

- [ ] **Backup strategy** defined (RTO/RPO objectives)
- [ ] **Backup storage location** decided (same region vs. cross-region)
- [ ] **Retention periods** documented
- [ ] **Restoration testing** schedule planned

### State File Management

- [ ] **S3 bucket** naming convention decided
- [ ] **Versioning** will be enabled on state bucket
- [ ] **Encryption** will be enabled (AES256 or KMS)
- [ ] **Backup strategy** for Terraform state defined

---

## Knowledge Requirements

### Team Skills Assessment

**Required knowledge:**
- [ ] AWS Organizations and multi-account strategies
- [ ] Terraform basics (resources, modules, state)
- [ ] VPC networking (subnets, routing, NAT, Transit Gateway)
- [ ] AWS security services (GuardDuty, Config, CloudTrail)
- [ ] IAM (roles, policies, SCPs)

**Nice to have:**
- [ ] AWS Control Tower experience
- [ ] Python scripting
- [ ] CI/CD with GitHub Actions
- [ ] Compliance frameworks (SOC2, PCI-DSS)

### Training Resources

If team needs training:
- AWS Well-Architected Framework
- AWS Organizations Best Practices
- Terraform Associate Certification
- AWS Security Fundamentals

---

## Pre-Deployment Checklist Summary

### Critical (Must Have)

- [ ] AWS account with Organizations capability
- [ ] Root account MFA enabled
- [ ] AWS CLI configured with appropriate credentials
- [ ] Terraform >= 1.5.0 installed
- [ ] Email addresses for new accounts
- [ ] CIDR blocks planned (non-overlapping)
- [ ] Budget approved
- [ ] Compliance requirements documented

### Important (Highly Recommended)

- [ ] Sandbox account for testing
- [ ] Service limits reviewed and increased
- [ ] Security scanning tools installed
- [ ] Team trained on procedures
- [ ] Communication plan established
- [ ] Rollback procedures documented

### Optional (Nice to Have)

- [ ] Test deployment completed
- [ ] Cost allocation tag strategy
- [ ] Reserved Instance strategy
- [ ] Advanced monitoring setup planned

---

## Sign-off

Before proceeding with deployment, obtain sign-off from:

- [ ] **Technical Lead:** Architecture and design approved
- [ ] **Security Team:** Security controls approved
- [ ] **Finance:** Budget approved
- [ ] **Management:** Project authorization confirmed

---

## Next Steps

Once all prerequisites are met, proceed to:
1. [Step-by-Step Deployment Guide](step-by-step-guide.md)
2. [Troubleshooting Guide](troubleshooting.md) (have this ready during deployment)

---

**Last Updated:** September 2025  
**Review Before Each Deployment**
