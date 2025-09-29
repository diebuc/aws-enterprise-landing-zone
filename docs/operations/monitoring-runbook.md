# Monitoring and Observability Runbook

## Overview

This runbook provides operational procedures for monitoring, alerting, and incident response in the AWS Enterprise Landing Zone. It covers daily health checks, alert response procedures, and troubleshooting workflows.

## Daily Health Checks

### Morning Checklist (08:00-09:00)

#### 1. Security Posture Review
```bash
# Check GuardDuty findings from last 24 hours
aws guardduty list-findings \
  --detector-id <detector-id> \
  --finding-criteria '{"Criterion":{"updatedAt":{"Gte":1695945600000}}}'

# Review Security Hub compliance score
aws securityhub get-findings \
  --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}' \
  --max-results 50
```

**Expected Results:**
- GuardDuty: 0 HIGH/CRITICAL findings
- Security Hub: >95% compliance score
- Config: All rules in COMPLIANT state

**Escalation:** Any CRITICAL findings → Immediate security team notification

#### 2. Cost and Usage Validation
```bash
# Check yesterday's spend vs. budget
aws ce get-cost-and-usage \
  --time-period Start=2025-09-28,End=2025-09-29 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Review cost anomalies
aws ce get-anomalies \
  --date-interval Start=2025-09-28,End=2025-09-29 \
  --max-results 10
```

**Thresholds:**
- Daily spend increase >20% → Investigate
- Cost anomaly detected → Review resource creation
- Budget forecast >90% → Alert finance team

#### 3. Service Health Check
```bash
# Check CloudWatch alarms in ALARM state
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --max-records 100

# Review Systems Manager compliance
aws ssm describe-instance-information \
  --filters "Key=PingStatus,Values=ConnectionLost"
```

**Expected Results:**
- 0 ALARM state alarms (or only expected maintenance)
- All managed instances responding to Systems Manager
- No unauthorized configuration changes

### Weekly Review (Monday 10:00)

#### 1. Capacity Planning
- Review CloudWatch metrics for resource utilization
- Check RDS storage space trends
- Analyze Transit Gateway bandwidth usage
- Review NAT Gateway data processing costs

#### 2. Security Compliance
- Run Config compliance report for all accounts
- Review IAM Access Analyzer findings
- Check for expiring SSL/TLS certificates
- Validate backup completion rates

#### 3. Cost Optimization
- Identify idle resources (EC2, RDS, EBS volumes)
- Review Reserved Instance utilization
- Analyze S3 storage class distribution
- Check for unattached EBS volumes and Elastic IPs

## Alert Response Procedures

### Critical Alerts (P1 - Immediate Response)

#### Root Account Usage Detected

**Alert:** `root-account-usage`  
**Severity:** CRITICAL  
**Response Time:** Immediate (5 minutes)

**Procedure:**
1. **Verify legitimacy:**
   ```bash
   # Check CloudTrail for root account activity
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=Username,AttributeValue=root \
     --max-results 50
   ```

2. **If unauthorized:**
   - Immediately contact AWS Support (Enterprise Support)
   - Initiate incident response procedure
   - Reset root account password
   - Enable MFA if not already enabled
   - Review all recent account changes

3. **If authorized:**
   - Document business justification
   - Verify action completed
   - Ensure root account secured again
   - Update incident log

**Post-Incident:**
- Review why root access was needed
- Implement controls to prevent future necessity
- Update procedures

#### Unauthorized API Calls Spike

**Alert:** `unauthorized-api-calls > 5 in 5 minutes`  
**Severity:** CRITICAL  
**Response Time:** 10 minutes

**Procedure:**
1. **Identify source:**
   ```bash
   # Query CloudWatch Logs Insights
   fields @timestamp, userIdentity.principalId, sourceIPAddress, errorCode, errorMessage
   | filter errorCode like /UnauthorizedOperation|AccessDenied/
   | sort @timestamp desc
   | limit 100
   ```

2. **Determine scope:**
   - Single user or multiple?
   - Single service or widespread?
   - Internal or external source IP?

3. **Immediate actions:**
   - If compromised credentials suspected:
     ```bash
     # Disable IAM user
     aws iam update-access-key \
       --access-key-id AKIAIOSFODNN7EXAMPLE \
       --status Inactive \
       --user-name username
     ```
   - If role compromise suspected: Revoke sessions
   - Block source IP if external attack

4. **Investigation:**
   - Review user's recent activity (24-48 hours)
   - Check for privilege escalation attempts
   - Verify no data exfiltration occurred

### High Priority Alerts (P2 - 30 minute response)

#### GuardDuty HIGH Severity Finding

**Alert:** `guardduty-high-severity`  
**Severity:** HIGH  
**Response Time:** 30 minutes

**Common Findings and Response:**

##### Cryptocurrency Mining
```bash
# Check EC2 instance details
aws ec2 describe-instances --instance-ids i-1234567890abcdef0

# Review network connections
aws ec2 describe-security-groups --group-ids sg-12345678

# Actions:
# 1. Isolate instance (change security group to deny-all)
# 2. Take snapshot for forensics
# 3. Terminate compromised instance
# 4. Launch replacement from clean AMI
```

##### Unusual API Call Pattern
```bash
# Investigate user activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=suspicious-user \
  --start-time 2025-09-29T00:00:00Z

# Actions:
# 1. Review legitimacy of activity
# 2. If suspicious: disable credentials
# 3. Force password reset / MFA re-enrollment
# 4. Review granted permissions
```

##### Data Exfiltration Attempt
```bash
# Check S3 access logs
aws s3api get-bucket-logging --bucket sensitive-data-bucket

# Review VPC Flow Logs for unusual egress
# CloudWatch Logs Insights query:
fields @timestamp, srcAddr, dstAddr, bytes
| filter action = "ACCEPT" and dstAddr not like /^10\./
| stats sum(bytes) as totalBytes by dstAddr
| sort totalBytes desc
| limit 20

# Actions:
# 1. Block suspicious destination IPs
# 2. Revoke access to affected resources
# 3. Enable S3 Object Lock if not already
# 4. Notify data protection officer
```

#### Console Sign-in Failures

**Alert:** `console-signin-failures > 3`  
**Severity:** HIGH  
**Response Time:** 30 minutes

**Procedure:**
1. **Check if brute force attack:**
   ```bash
   # Query failed sign-ins
   fields @timestamp, userIdentity.principalId, sourceIPAddress, errorMessage
   | filter eventName = "ConsoleLogin" and errorMessage = "Failed authentication"
   | stats count() as attempts by sourceIPAddress
   | sort attempts desc
   ```

2. **If brute force detected:**
   - Block source IP at WAF/Network Firewall level
   - Notify affected user
   - Force password reset
   - Enable MFA if not already

3. **If legitimate user lockout:**
   - Verify user identity through alternative channel
   - Reset password following secure procedure
   - Document incident

### Medium Priority Alerts (P3 - 2 hour response)

#### IAM Policy Changes

**Alert:** `iam-policy-changes`  
**Severity:** MEDIUM  
**Response Time:** 2 hours

**Procedure:**
1. **Review change details:**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=EventName,AttributeValue=PutRolePolicy \
     --max-results 50
   ```

2. **Validate:**
   - Change ticket exists?
   - Authorized by change approval process?
   - Follows least privilege principle?

3. **If unauthorized:**
   - Revert policy change
   - Investigate who made change and why
   - Review related changes by same principal

4. **If authorized but concerning:**
   - Review with security team
   - Document justification
   - Schedule follow-up review

## Troubleshooting Workflows

### Issue: High CloudWatch Costs

**Symptoms:**
- CloudWatch bill increased significantly
- Log ingestion costs spiking

**Investigation:**
```bash
# Identify log groups by size
aws logs describe-log-groups \
  --query 'logGroups[*].[logGroupName,storedBytes]' \
  --output table | sort -k2 -n -r

# Check log group growth rate
aws cloudwatch get-metric-statistics \
  --namespace AWS/Logs \
  --metric-name IncomingBytes \
  --dimensions Name=LogGroupName,Value=/aws/lambda/function-name \
  --start-time 2025-09-22T00:00:00Z \
  --end-time 2025-09-29T00:00:00Z \
  --period 86400 \
  --statistics Sum
```

**Resolution:**
1. Implement log retention policies:
   ```bash
   aws logs put-retention-policy \
     --log-group-name /aws/lambda/verbose-function \
     --retention-in-days 7
   ```

2. Enable log filtering at source
3. Move infrequently accessed logs to S3
4. Review application logging levels

### Issue: Transit Gateway Data Transfer Spike

**Symptoms:**
- Unexpected Transit Gateway costs
- Bandwidth utilization increased

**Investigation:**
```bash
# Check Transit Gateway metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/TransitGateway \
  --metric-name BytesIn \
  --dimensions Name=TransitGateway,Value=tgw-12345678 \
  --start-time 2025-09-22T00:00:00Z \
  --end-time 2025-09-29T00:00:00Z \
  --period 3600 \
  --statistics Sum

# Analyze VPC Flow Logs to identify source
fields @timestamp, srcAddr, dstAddr, bytes, protocol
| filter interfaceId like /eni-transit/
| stats sum(bytes) as totalBytes by srcAddr, dstAddr
| sort totalBytes desc
| limit 50
```

**Resolution:**
1. Identify chatty applications
2. Optimize data transfer patterns
3. Consider VPC peering for high-volume connections
4. Implement data caching strategies

### Issue: Config Compliance Violations

**Symptoms:**
- Config rules reporting NON_COMPLIANT
- Security Hub compliance score dropped

**Investigation:**
```bash
# List non-compliant resources
aws configservice describe-compliance-by-config-rule \
  --compliance-types NON_COMPLIANT

# Get details of specific violation
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name encrypted-volumes \
  --compliance-types NON_COMPLIANT
```

**Resolution:**
1. **For encryption violations:**
   ```bash
   # Enable default encryption
   aws ec2 enable-ebs-encryption-by-default --region us-east-1
   
   # Re-launch instances with encrypted volumes
   ```

2. **For public access violations:**
   ```bash
   # Block S3 public access
   aws s3api put-public-access-block \
     --bucket my-bucket \
     --public-access-block-configuration \
     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```

3. **For IAM violations:**
   - Review password policy
   - Enforce MFA
   - Remove overly permissive policies

## Performance Monitoring

### Key Performance Indicators (KPIs)

#### Infrastructure Health
- **EC2 CPU Utilization:** Target <70% average, <90% peak
- **RDS Connection Count:** <80% of max connections
- **ELB Healthy Host Count:** 100% of registered targets
- **Lambda Error Rate:** <1%

#### Security Metrics
- **Mean Time to Detection (MTTD):** <15 minutes
- **Mean Time to Response (MTTR):** <1 hour for critical
- **Security Hub Score:** >95%
- **GuardDuty HIGH/CRITICAL:** 0 active findings

#### Cost Efficiency
- **Reserved Instance Utilization:** >90%
- **Spot Instance Adoption:** >30% for eligible workloads
- **S3 Glacier Migration:** >60% of older data
- **Idle Resource Rate:** <5%

### Monitoring Dashboard URLs

**Production:**
- Security Operations: `https://console.aws.amazon.com/cloudwatch/dashboards/security-ops`
- Cost Dashboard: `https://console.aws.amazon.com/cost-management/home`
- GuardDuty: `https://console.aws.amazon.com/guardduty/home`

## Escalation Procedures

### Severity Definitions

| Severity | Description | Response Time | Escalation |
|----------|-------------|---------------|------------|
| P1 - Critical | Security breach, complete service outage | 5 minutes | Immediate to on-call engineer + manager |
| P2 - High | Partial service degradation, high security finding | 30 minutes | On-call engineer, manager notification |
| P3 - Medium | Minor service impact, medium security finding | 2 hours | Standard on-call rotation |
| P4 - Low | No service impact, informational | Next business day | Queue for team review |

### Contact Information

**On-Call Rotation:** PagerDuty schedule  
**Security Team:** security-team@company.com  
**AWS Support:** Enterprise Support ticket system

### Escalation Path

```
P1 Alert
  ↓
On-Call Engineer (5 min)
  ↓
Team Lead (15 min if not resolved)
  ↓
Director of Infrastructure (30 min if not resolved)
  ↓
CTO (1 hour if not resolved)
```

## Maintenance Windows

### Standard Maintenance

**Schedule:** Saturday 02:00-06:00 UTC  
**Frequency:** Monthly (first Saturday)  
**Activities:**
- OS patching
- Minor version upgrades
- Configuration updates
- Performance tuning

**Pre-maintenance checklist:**
- [ ] Notify stakeholders 7 days in advance
- [ ] Create backup snapshots
- [ ] Test changes in staging
- [ ] Prepare rollback plan
- [ ] Update change ticket

### Emergency Maintenance

**Trigger:** Critical security vulnerability or major incident  
**Approval:** Director+ level  
**Communication:** Immediate notification to all stakeholders

## Reporting

### Daily Reports (Automated)

**Recipients:** Operations team  
**Delivery:** 09:00 UTC via email  
**Contents:**
- Security findings summary
- Cost vs. budget
- Service health status
- Top 5 alarms

### Weekly Reports

**Recipients:** Management  
**Delivery:** Monday 10:00 UTC  
**Contents:**
- Week-over-week cost comparison
- Security posture trends
- Capacity utilization
- Upcoming actions

### Monthly Executive Summary

**Recipients:** C-level  
**Delivery:** First business day of month  
**Contents:**
- Financial summary
- Security incidents and resolutions
- Infrastructure growth
- Strategic recommendations

## Related Documentation

- [Incident Response Procedures](incident-response.md)
- [Disaster Recovery Runbook](disaster-recovery.md)
- [Security Policies](security-policies.md)
- [Cost Optimization Guide](cost-optimization.md)

---

**Last Updated:** September 2025  
**Owner:** Operations Team  
**Review Schedule:** Monthly  
**Next Review:** October 2025
