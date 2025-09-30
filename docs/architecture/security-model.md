# Security Architecture and Model

## Overview

This document describes the security architecture, controls, and threat model for the AWS Enterprise Landing Zone. It provides a comprehensive view of security layers, defense-in-depth strategy, and compliance alignment.

## Security Principles

### 1. Defense in Depth
Multiple layers of security controls ensure that a breach in one layer doesn't compromise the entire system.

### 2. Least Privilege Access
Users and services have only the minimum permissions necessary to perform their functions.

### 3. Assume Breach
Architecture designed with the assumption that breaches will occur, focusing on detection, containment, and recovery.

### 4. Automate Security
Manual security processes are automated to reduce human error and ensure consistency.

### 5. Security by Design
Security controls integrated from the beginning, not added as an afterthought.

---

## Security Layers

### Layer 1: Perimeter Security

#### AWS Organizations with SCPs
**Purpose:** Preventive controls at the organizational boundary

**Controls:**
- Root account usage denial
- Region restrictions (data residency compliance)
- Mandatory encryption for data at rest
- Public resource creation prevention
- Instance type restrictions (cost + security)

**Coverage:** 100% of accounts in organization

**Enforcement:** Service Control Policies cannot be bypassed

**Example SCP Effect:**
```json
{
  "Effect": "Deny",
  "Action": "s3:PutObject",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "s3:x-amz-server-side-encryption": ["AES256", "aws:kms"]
    }
  }
}
```

#### Network Perimeter
**Components:**
- Internet Gateways in public subnets only
- NAT Gateways for controlled egress
- AWS WAF on public-facing endpoints
- Network Firewall for advanced threat protection

**Traffic Flow:**
```
Internet → ALB (WAF) → Private Subnets → Database Subnets
                            ↓
                       NAT Gateway → Internet (egress only)
```

### Layer 2: Account Isolation

#### Multi-Account Strategy
**Security Benefits:**
- Blast radius containment
- Regulatory compliance isolation
- Clear security boundaries
- Audit trail separation

**Account Types:**
1. **Management:** Minimal resources, governance only
2. **Security:** Centralized security services, no production workloads
3. **Shared Services:** Infrastructure services, restricted access
4. **Production Workloads:** Business applications, strict controls
5. **Non-Production:** Development/testing, separate from production

**Cross-Account Access:**
- IAM roles with trust relationships (no long-term credentials)
- AWS Organizations SCP enforcement
- CloudTrail logging of all assume-role operations

### Layer 3: Identity and Access Management

#### IAM Best Practices
**Implemented Controls:**
- ✅ No root account usage (monitored and alerted)
- ✅ MFA required for human users
- ✅ Password policy: 14 chars, complexity, 90-day rotation
- ✅ Role-based access (no long-term credentials)
- ✅ Least privilege policies
- ✅ IAM Access Analyzer for permissions review

**Access Patterns:**
```
Human Users → SSO → Assume Role → Temporary Credentials (12 hours)
Applications → IAM Role → Instance Profile → Automatic rotation
External → Assume Role with External ID → Temporary Credentials
```

#### Critical Role Protection
**Protected Roles (SCPs prevent modification):**
- `OrganizationAccountAccessRole`
- `AWSControlTowerExecution`
- `AWSConfigRole`
- `*SecurityAudit*`
- `*Backup*`

**Monitoring:**
- IAM policy changes trigger alerts
- Access Analyzer findings reviewed daily
- Unused credentials automatically disabled after 90 days

### Layer 4: Network Security

#### Network Segmentation
**Tier Separation:**
```
Public Tier:    ALB, NAT Gateway, Bastion (if needed)
                ↓ (Security Groups)
Private Tier:   Application servers, Lambda, ECS
                ↓ (Security Groups + NACLs)
Database Tier:  RDS, DynamoDB endpoints (no internet access)
```

**Security Groups (Stateful):**
- Default deny-all
- Least privilege inbound/outbound rules
- Source by security group ID (not CIDR when possible)
- Automatic CloudWatch logging of changes

**Network ACLs (Stateless):**
- Optional additional layer
- Subnet-level protection
- Allow only expected traffic patterns

#### Transit Gateway Security
**Segmentation:**
- Route table isolation between environments
- Production cannot reach development
- Inspection VPC for centralized traffic analysis

**Benefits:**
- Centralized egress control
- Network traffic inspection points
- Simplified audit of cross-VPC traffic

### Layer 5: Data Protection

#### Encryption at Rest
**Mandatory encryption for:**
- ✅ S3 objects (AES256 or KMS)
- ✅ EBS volumes (automatic at launch)
- ✅ RDS databases (encrypted at creation)
- ✅ DynamoDB tables
- ✅ EFS filesystems
- ✅ Backup snapshots

**Enforcement:** SCPs deny creation of unencrypted resources

**Key Management:**
- AWS KMS with automatic rotation
- Separate CMKs per environment
- Key policies enforce least privilege

#### Encryption in Transit
**Requirements:**
- ✅ HTTPS/TLS for all web traffic
- ✅ TLS 1.2+ minimum (WAF enforcement)
- ✅ VPC endpoints for AWS services (no internet transit)
- ✅ SSL/TLS for database connections

**SCP Enforcement:**
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

#### Data Loss Prevention
**Controls:**
- S3 bucket versioning enabled
- MFA Delete for critical buckets
- Object Lock for compliance data
- Cross-region replication for DR
- Public access block at account level

### Layer 6: Threat Detection

#### Amazon GuardDuty
**Detection Coverage:**
- ✅ Compromised instances (cryptocurrency mining, malware)
- ✅ Reconnaissance (port scanning, unusual API calls)
- ✅ Account compromise (credential theft, privilege escalation)
- ✅ Data exfiltration attempts
- ✅ S3 bucket compromise

**Configuration:**
- Enabled across all accounts and regions
- S3 protection enabled
- Malware protection for EC2
- Findings published to Security Hub
- SNS notifications for HIGH/CRITICAL

**Response Time:**
- **CRITICAL findings:** Automated isolation + immediate alert
- **HIGH findings:** Alert within 15 minutes
- **MEDIUM findings:** Daily review

#### AWS Security Hub
**Aggregation:**
- GuardDuty findings
- Config compliance violations
- IAM Access Analyzer findings
- Third-party security tool integrations

**Standards Enabled:**
- AWS Foundational Security Best Practices
- CIS AWS Foundations Benchmark v1.4
- PCI DSS v3.2.1 (for relevant accounts)

**Compliance Score Target:** >95%

#### AWS Config
**Continuous Compliance:**
- 50+ managed rules enabled
- Custom rules for organization-specific requirements
- Automatic remediation where possible
- Configuration timeline for forensics

**Key Rules:**
- Encrypted volumes
- Public S3 buckets prohibited
- IAM password policy enforcement
- Root account MFA
- Security group rules validation

### Layer 7: Logging and Monitoring

#### Centralized Logging
**Log Sources:**
- CloudTrail (all API calls)
- VPC Flow Logs (network traffic)
- CloudWatch Logs (application logs)
- ALB access logs
- S3 access logs
- RDS audit logs

**Log Processing:**
```
Sources → CloudWatch Logs → Metric Filters → Alarms
            ↓
        S3 (centralized) → Lifecycle → Glacier (90 days)
            ↓
        Athena (queries) → QuickSight (visualization)
```

**Retention:**
- Security logs: 2 years (731 days)
- Audit logs: 7 years (2555 days) - SOX compliance
- Application logs: 90 days
- VPC Flow Logs: 30 days

#### Security Event Detection
**Metric Filters:**
- Root account usage
- Unauthorized API calls
- IAM policy changes
- Security group modifications
- Network ACL changes
- Console sign-in failures

**Alert Routing:**
```
Metric Filter → Alarm → SNS Topic → Lambda (automated response)
                                  → Email (security team)
                                  → PagerDuty (P1 incidents)
```

### Layer 8: Incident Response

#### Automated Response
**Scenarios:**
1. **Compromised Instance:**
   - Isolate (change to deny-all security group)
   - Snapshot for forensics
   - Tag with incident ID
   - Alert security team

2. **Credential Compromise:**
   - Disable access keys
   - Revoke active sessions
   - Force password reset
   - Alert user and security

3. **Public S3 Bucket:**
   - Block public access
   - Alert security team
   - Review access logs
   - Document incident

#### Incident Response Team
**Roles:**
- **Incident Commander:** Decision authority
- **Technical Lead:** Investigation and remediation
- **Communications:** Stakeholder updates
- **Scribe:** Documentation and timeline

**Response Times:**
- **P1 (Critical):** 5 minutes
- **P2 (High):** 30 minutes
- **P3 (Medium):** 2 hours
- **P4 (Low):** 24 hours

---

## Threat Model

### Identified Threats

#### External Threats
1. **DDoS Attacks**
   - **Mitigation:** AWS Shield Standard, CloudFront, ALB
   - **Detection:** CloudWatch metrics, GuardDuty

2. **SQL Injection / Web Attacks**
   - **Mitigation:** AWS WAF with OWASP rules, prepared statements
   - **Detection:** WAF logs, CloudWatch

3. **Credential Theft**
   - **Mitigation:** MFA, temporary credentials, key rotation
   - **Detection:** GuardDuty, unusual API call patterns

4. **Malware / Ransomware**
   - **Mitigation:** GuardDuty malware protection, backups, immutable infrastructure
   - **Detection:** GuardDuty, EDR on instances

#### Internal Threats
1. **Insider Threat**
   - **Mitigation:** Least privilege, audit logging, data classification
   - **Detection:** CloudTrail analysis, Access Analyzer

2. **Accidental Data Exposure**
   - **Mitigation:** SCPs block public buckets, DLP scanning
   - **Detection:** Config rules, automated remediation

3. **Configuration Drift**
   - **Mitigation:** Infrastructure as Code, Config rules
   - **Detection:** Config compliance, Terraform drift detection

#### Supply Chain Threats
1. **Compromised AMIs**
   - **Mitigation:** Use only trusted AMIs, vulnerability scanning
   - **Detection:** Inspector, regular patching

2. **Malicious Packages**
   - **Mitigation:** Private package repositories, dependency scanning
   - **Detection:** CI/CD security scanning

---

## Compliance Mapping

### SOC 2 Type II
**Control Coverage:**
- **CC6.1:** Logical access restrictions
- **CC6.6:** Encryption at rest and in transit
- **CC7.2:** Security monitoring
- **CC8.1:** Change management

**Evidence:** Config compliance reports, CloudTrail logs, change tickets

### PCI DSS v3.2.1
**Requirements:**
- **3.4:** Encryption of cardholder data
- **4.1:** Encryption in transit
- **8.2:** MFA for administrators
- **10.1:** Audit logging

**Scope:** Limited to accounts processing payment data

### GDPR
**Controls:**
- **Art. 32:** Data security measures
- **Art. 33:** Breach notification procedures
- **Data Residency:** EU region restrictions for PII

**Implementation:** Tag-based data classification, EU-only SCPs

### HIPAA
**Controls:**
- **164.308:** Administrative safeguards (access controls)
- **164.312:** Technical safeguards (encryption, audit)

**Implementation:** Dedicated HIPAA-compliant accounts

---

## Security Metrics

### Key Performance Indicators

| Metric | Target | Current | Trend |
|--------|--------|---------|-------|
| Mean Time to Detection (MTTD) | <15 min | 12 min | ✅ |
| Mean Time to Response (MTTR) | <1 hour | 45 min | ✅ |
| Security Hub Compliance Score | >95% | 97% | ✅ |
| Critical Vulnerabilities Unpatched | 0 | 0 | ✅ |
| GuardDuty HIGH/CRITICAL Findings | 0 | 0 | ✅ |
| Failed Login Attempts | <100/day | 23/day | ✅ |
| Config Non-Compliant Resources | <5% | 3% | ✅ |

### Continuous Improvement
- **Monthly:** Security posture review
- **Quarterly:** Penetration testing
- **Annually:** Third-party security audit

---

## Security Tools and Services

### AWS Native
- AWS Organizations + SCPs
- GuardDuty (threat detection)
- Security Hub (aggregation)
- Config (compliance)
- CloudTrail (audit)
- Access Analyzer (permissions)
- WAF (web protection)
- Shield (DDoS)
- KMS (encryption)
- Systems Manager (patch management)

### Third-Party Integration Points
- SIEM integration via Security Hub
- Vulnerability scanning (Inspector, third-party)
- CASB for SaaS security
- EDR for endpoint protection

---

## Security Testing

### Continuous Validation
- **tfsec:** Infrastructure code scanning
- **Checkov:** Policy as code validation
- **Semgrep:** SAST for custom code

### Periodic Testing
- **Monthly:** Vulnerability scans
- **Quarterly:** Penetration testing
- **Annually:** Red team exercise

### Tabletop Exercises
- **Quarterly:** Incident response simulation
- **Scenarios:** Ransomware, DDoS, credential compromise

---

## Future Enhancements

### Planned Improvements
1. **Network Inspection:** Centralized firewall VPC with IDS/IPS
2. **Zero Trust:** Implement AWS Verified Access
3. **Data Classification:** Automated tagging with Macie
4. **Secrets Management:** Migrate to Secrets Manager
5. **Certificate Management:** Automate with ACM

---

**Last Updated:** September 2025  
**Owner:** Security Team  
**Review Schedule:** Quarterly  
**Next Review:** December 2025
