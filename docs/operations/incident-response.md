# Incident Response Procedures

## Overview

This document defines procedures for responding to security incidents in the AWS Enterprise Landing Zone. It provides step-by-step workflows for detection, containment, eradication, recovery, and post-incident activities.

## Incident Classification

### Security Incidents

| Class | Description | Examples | Response Time |
|-------|-------------|----------|---------------|
| **S1 - Critical** | Active breach, data exfiltration, ransomware | Root account compromise, mass data deletion, cryptomining outbreak | Immediate (5 min) |
| **S2 - High** | Attempted breach, privilege escalation, malware detection | Brute force attacks, suspicious IAM changes, GuardDuty HIGH findings | 15 minutes |
| **S3 - Medium** | Policy violations, suspicious activity, failed attacks | Multiple failed authentications, config drift, medium findings | 2 hours |
| **S4 - Low** | Informational, potential issues | Single failed login, informational findings, audit anomalies | 24 hours |

## Incident Response Team

### Roles and Responsibilities

#### Incident Commander (IC)
- **Who:** On-call senior engineer or security lead
- **Responsibilities:**
  - Overall incident coordination
  - Decision-making authority
  - Communication with stakeholders
  - Post-incident review facilitation

#### Technical Lead
- **Who:** Subject matter expert for affected system
- **Responsibilities:**
  - Technical investigation
  - Implement containment measures
  - Execute recovery procedures
  - Document technical findings

#### Communications Lead
- **Who:** Manager or designated communications person
- **Responsibilities:**
  - Stakeholder updates
  - External communications (if needed)
  - Status page updates
  - Post-incident communication

#### Scribe
- **Who:** Team member assigned during incident
- **Responsibilities:**
  - Timeline documentation
  - Action item tracking
  - Capture all decisions and changes
  - Generate incident report

## S1 - Critical Security Incident Response

### Phase 1: Detection and Initial Response (0-15 minutes)

#### Step 1: Incident Confirmation
```bash
# Verify the incident is real, not false positive
aws cloudtrail lookup-events \
  --max-results 100 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=<suspicious-event>

# Check GuardDuty for corroborating evidence
aws guardduty list-findings \
  --detector-id <detector-id> \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}'
```

**Decision Point:** Is this a confirmed security incident?
- **Yes:** Proceed to Step 2
- **No:** Document as false positive, update detection rules

#### Step 2: Activate Incident Response Team
```
# Use PagerDuty or similar
1. Page Incident Commander
2. Assemble core team via Slack #security-incidents channel
3. Establish Zoom war room
4. Assign roles (IC, Technical Lead, Communications, Scribe)
```

#### Step 3: Initial Assessment
- **Scope:** Single account or organization-wide?
- **Asset:** What systems/data are affected?
- **Impact:** Active data breach or attempted?
- **Source:** Internal or external threat actor?

### Phase 2: Containment (15-60 minutes)

#### Immediate Containment Actions

##### Compromised IAM Credentials
```bash
# 1. Disable access keys immediately
aws iam update-access-key \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive \
  --user-name compromised-user

# 2. Revoke all active sessions
aws iam delete-user-policy \
  --user-name compromised-user \
  --policy-name AdministratorAccess

# 3. Force password reset
aws iam update-login-profile \
  --user-name compromised-user \
  --password-reset-required
```

##### Compromised EC2 Instance
```bash
# 1. Isolate instance (deny-all security group)
aws ec2 modify-instance-attribute \
  --instance-id i-1234567890abcdef0 \
  --groups sg-deny-all

# 2. Take snapshot for forensics
aws ec2 create-snapshot \
  --volume-id vol-1234567890abcdef0 \
  --description "Forensic snapshot - Incident #2025-001" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Incident,Value=2025-001}]'

# 3. Tag instance for investigation
aws ec2 create-tags \
  --resources i-1234567890abcdef0 \
  --tags Key=Status,Value=Quarantined Key=Incident,Value=2025-001

# DO NOT terminate yet - preserve evidence
```

##### Compromised S3 Bucket (Data Exfiltration)
```bash
# 1. Enable S3 Object Lock (if not already)
aws s3api put-object-lock-configuration \
  --bucket sensitive-bucket \
  --object-lock-configuration '{"ObjectLockEnabled":"Enabled","Rule":{"DefaultRetention":{"Mode":"GOVERNANCE","Days":1}}}'

# 2. Block all public access
aws s3api put-public-access-block \
  --bucket sensitive-bucket \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 3. Revoke bucket policy if public
aws s3api delete-bucket-policy --bucket sensitive-bucket

# 4. Enable MFA Delete
aws s3api put-bucket-versioning \
  --bucket sensitive-bucket \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::123456789012:mfa/user MFA-CODE"
```

##### Ransomware/Cryptomining
```bash
# 1. Isolate ALL affected instances immediately
for instance in $(aws ec2 describe-instances \
  --filters "Name=tag:Suspicious,Values=true" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text); do
    aws ec2 modify-instance-attribute \
      --instance-id $instance \
      --groups sg-deny-all
    echo "Isolated $instance"
done

# 2. Snapshot all affected volumes
# 3. Terminate instances after snapshots complete
# 4. Deploy clean replacement instances from golden AMIs
```

### Phase 3: Investigation and Eradication (1-4 hours)

#### Forensic Data Collection

```bash
# 1. Collect CloudTrail logs
aws cloudtrail lookup-events \
  --start-time 2025-09-28T00:00:00Z \
  --max-results 1000 \
  --output json > incident-cloudtrail.json

# 2. Export VPC Flow Logs
aws logs create-export-task \
  --log-group-name /aws/vpc/flowlogs \
  --from 1695859200000 \
  --to 1695945600000 \
  --destination incident-forensics-bucket \
  --destination-prefix vpc-flow-logs/

# 3. Collect GuardDuty findings
aws guardduty get-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-ids> \
  --output json > guardduty-findings.json

# 4. Export relevant S3 access logs
aws s3 sync s3://logging-bucket/s3-access-logs/ \
  ./forensics/s3-logs/ \
  --exclude "*" \
  --include "*2025-09-29*"
```

#### Root Cause Analysis

**Questions to answer:**
1. **Initial access:** How did attacker gain entry?
2. **Lateral movement:** What other systems accessed?
3. **Persistence:** Did attacker establish backdoors?
4. **Data impact:** Was data accessed, modified, or exfiltrated?
5. **Timeline:** Complete chronology of attacker activity

#### Eradication Steps

1. **Remove attacker access:**
   - Delete unauthorized IAM users/roles
   - Revoke all sessions
   - Rotate all potentially compromised credentials

2. **Patch vulnerabilities:**
   - Apply security patches
   - Fix misconfigurations
   - Update security groups/NACLs

3. **Remove malware:**
   - Terminate compromised instances
   - Launch clean replacements
   - Scan attached volumes before reuse

### Phase 4: Recovery (4-24 hours)

#### Service Restoration

```bash
# 1. Deploy clean infrastructure from IaC
cd terraform/
terraform plan -out recovery.tfplan
terraform apply recovery.tfplan

# 2. Restore data from backups
aws backup start-restore-job \
  --recovery-point-arn arn:aws:backup:us-east-1:123456789012:recovery-point:xxxxx \
  --iam-role-arn arn:aws:iam::123456789012:role/BackupRestoreRole \
  --metadata file://restore-metadata.json

# 3. Validate data integrity
# Run checksums, verify record counts, test functionality

# 4. Gradually restore service
# Blue-green deployment or canary rollout
```

#### Post-Recovery Validation

- [ ] All services operational
- [ ] Data integrity verified
- [ ] No remaining attacker presence
- [ ] All credentials rotated
- [ ] Monitoring confirms normal behavior
- [ ] Stakeholders notified of recovery

### Phase 5: Post-Incident Activities (24 hours - 1 week)

#### Incident Report

**Template:**
```markdown
# Security Incident Report: 2025-001

## Executive Summary
Brief description of incident, impact, and resolution

## Timeline
| Time | Event |
|------|-------|
| 14:23 | Initial detection via GuardDuty alert |
| 14:28 | Incident response team assembled |
| 14:35 | Compromised credentials disabled |
| ... | ... |

## Root Cause
Detailed analysis of how incident occurred

## Impact Assessment
- Systems affected: [list]
- Data compromised: [assessment]
- Business impact: [financial, reputational, operational]
- Customers affected: [number and notification status]

## Response Effectiveness
What worked well, what didn't

## Lessons Learned
Key takeaways and improvements identified

## Action Items
| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Implement MFA for all users | Security | 2025-10-15 | In Progress |
| ... | ... | ... | ... |
```

#### Lessons Learned Meeting

**Attendees:** Full incident response team + management  
**Timing:** Within 5 business days of incident closure  
**Duration:** 1-2 hours

**Agenda:**
1. Timeline review
2. What went well?
3. What could be improved?
4. Action items with owners and due dates
5. Update runbooks and procedures

#### Corrective Actions

**Categories:**
- **Technical:** Implement new controls, patch systems
- **Process:** Update procedures, add checks
- **People:** Training, awareness, staffing
- **Technology:** New tools, upgraded monitoring

## Common Incident Scenarios

### Scenario 1: Phishing Attack Leading to Credential Compromise

**Indicators:**
- Suspicious emails reported
- Login from unusual location
- Unusual API activity

**Response:**
1. Disable compromised account
2. Force password reset for affected users
3. Enable MFA for all users
4. Review email logs for other victims
5. Block sender domains
6. Security awareness training

### Scenario 2: Insider Threat - Unauthorized Data Access

**Indicators:**
- Access to data outside job role
- Large data downloads
- Access outside business hours

**Response:**
1. Preserve all evidence (don't alert user yet)
2. Coordinate with HR and Legal
3. Collect complete audit trail
4. Revoke access only after evidence secured
5. Follow company insider threat procedures

### Scenario 3: Misconfiguration Leading to Data Exposure

**Indicators:**
- Config compliance violation
- Public S3 bucket discovered
- Security Hub finding

**Response:**
1. Immediately remediate misconfiguration
2. Assess what data was exposed and for how long
3. Review access logs to determine if data was accessed
4. Notify affected parties if required (GDPR, etc.)
5. Implement preventive controls (SCPs, automated remediation)

## Legal and Regulatory Considerations

### Data Breach Notification Requirements

#### GDPR (EU)
- **Timeline:** 72 hours to notify supervisory authority
- **Threshold:** Risk to rights and freedoms of individuals
- **Documentation:** Maintain records of all breaches

#### PCI DSS
- **Timeline:** Immediately notify payment brands and acquirer
- **Threshold:** Any compromise of cardholder data
- **Documentation:** Forensic investigation required

### Evidence Preservation

**Critical steps:**
1. **Do not** alter or destroy any evidence
2. Maintain chain of custody for all forensic data
3. Use forensically sound methods for data collection
4. Document all actions and timestamps
5. Store evidence securely with access controls

### Working with Law Enforcement

**When to involve:**
- Active cyberattack in progress
- Suspected nation-state actor
- Criminal activity (fraud, extortion)
- Required by regulation

**How to engage:**
- Contact FBI Cyber Division or IC3
- Provide detailed incident report
- Offer full cooperation
- Maintain communication channel

## Tabletop Exercises

### Quarterly Exercise Schedule

**Q1:** Ransomware scenario  
**Q2:** Insider threat  
**Q3:** DDoS attack  
**Q4:** Data breach

### Exercise Format

**Duration:** 2 hours  
**Participants:** Full IR team + key stakeholders  
**Facilitation:** External security consultant (recommended)

**Outcomes:**
- Validate procedures
- Identify gaps
- Build team coordination
- Satisfy compliance requirements

## Tools and Resources

### Incident Response Tools

- **CloudTrail Log Analysis:** AWS Athena queries
- **Log Aggregation:** CloudWatch Logs Insights
- **Forensics:** EC2 memory dump, disk imaging
- **Communication:** Slack #security-incidents, Zoom war room
- **Ticketing:** JIRA Security Incidents project

### Reference Materials

- [AWS Security Incident Response Guide](https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/)
- [NIST Incident Handling Guide (SP 800-61)](https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final)
- [SANS Incident Handler's Handbook](https://www.sans.org/white-papers/33901/)

## Contact Information

**Security Team:** security@company.com  
**AWS Support:** Enterprise Support console  
**Legal:** legal@company.com  
**PR/Communications:** pr@company.com  
**FBI Cyber:** local field office or IC3.gov

---

**Last Updated:** September 2025  
**Owner:** Security Team  
**Review Schedule:** Quarterly  
**Next Tabletop Exercise:** December 2025
