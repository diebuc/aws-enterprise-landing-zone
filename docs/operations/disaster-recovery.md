# Disaster Recovery Runbook

## Overview

This runbook provides procedures for disaster recovery (DR) in the AWS Enterprise Landing Zone. It covers backup strategies, failover procedures, and recovery processes for various disaster scenarios.

## Recovery Objectives

### Service Level Objectives (SLOs)

| Tier | Service Type | RTO | RPO | Availability Target |
|------|--------------|-----|-----|---------------------|
| **Tier 1 - Critical** | Production databases, authentication services | 4 hours | 1 hour | 99.9% |
| **Tier 2 - Important** | Application servers, APIs, web services | 8 hours | 4 hours | 99.5% |
| **Tier 3 - Standard** | Internal tools, reporting systems | 24 hours | 24 hours | 99.0% |
| **Tier 4 - Low Priority** | Development, test environments | 72 hours | 7 days | 95.0% |

### Definitions

- **RTO (Recovery Time Objective):** Maximum acceptable time to restore service
- **RPO (Recovery Point Objective):** Maximum acceptable data loss measured in time
- **MTTR (Mean Time To Recovery):** Average time to recover from incidents

## DR Architecture

### Multi-Region Strategy

**Primary Region:** us-east-1 (N. Virginia)  
**Secondary Region:** us-west-2 (Oregon)  
**DR Region:** eu-west-1 (Ireland)

### Backup Strategy

```
Production Data
├── Real-time Replication → Secondary Region (hot standby)
├── Hourly Snapshots → Same region (quick recovery)
├── Daily Backups → DR Region (disaster protection)
└── Weekly Archives → Glacier Deep Archive (compliance)
```

## Backup Procedures

### Automated Backups

#### RDS Database Backups

```bash
# Verify automated backup configuration
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,BackupRetentionPeriod,PreferredBackupWindow]' \
  --output table

# Expected:
# - BackupRetentionPeriod: 35 days minimum
# - PreferredBackupWindow: 02:00-04:00 UTC
# - Multi-AZ: Enabled for production

# Manual snapshot for major changes
aws rds create-db-snapshot \
  --db-instance-identifier prod-database \
  --db-snapshot-identifier prod-db-pre-migration-2025-09-29
```

#### EBS Volume Snapshots

```bash
# Create snapshot with lifecycle policy
aws dlm create-lifecycle-policy \
  --execution-role-arn arn:aws:iam::123456789012:role/AWSDataLifecycleManager \
  --description "Daily EBS snapshots with 30-day retention" \
  --state ENABLED \
  --policy-details file://snapshot-policy.json

# Manual snapshot for critical volumes
aws ec2 create-snapshot \
  --volume-id vol-1234567890abcdef0 \
  --description "Pre-upgrade snapshot - $(date +%Y-%m-%d)" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Backup,Value=Manual},{Key=Date,Value=2025-09-29}]'

# Copy snapshot to DR region
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id snap-1234567890abcdef0 \
  --destination-region eu-west-1 \
  --description "DR copy from us-east-1"
```

#### S3 Cross-Region Replication

```bash
# Verify replication status
aws s3api get-bucket-replication \
  --bucket production-data-bucket

# Check replication metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name ReplicationLatency \
  --dimensions Name=SourceBucket,Value=production-data-bucket \
  --start-time 2025-09-28T00:00:00Z \
  --end-time 2025-09-29T00:00:00Z \
  --period 3600 \
  --statistics Average
```

### Backup Validation

#### Monthly Backup Testing

**Schedule:** Last Saturday of each month  
**Duration:** 4 hours  
**Scope:** Restore one tier-1 service to isolated environment

```bash
# Test RDS restore
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier test-restore-$(date +%Y%m%d) \
  --db-snapshot-identifier prod-db-snapshot-latest \
  --db-subnet-group-name test-subnet-group \
  --no-publicly-accessible \
  --tags Key=Purpose,Value=DR-Test Key=Date,Value=$(date +%Y-%m-%d)

# Validate data integrity
# Run application tests against restored database
# Document results in DR test report
# Delete test resources after validation
```

## Disaster Scenarios and Response

### Scenario 1: Regional Outage (Complete AZ Failure)

**Indicators:**
- Multiple availability zone failures
- AWS Health Dashboard showing region-wide issues
- Services unable to reach resources in primary region

**Response Procedure:**

#### Phase 1: Assessment (0-15 minutes)

```bash
# Check AWS Health Dashboard
aws health describe-events \
  --filter eventTypeCategories=issue,accountSpecific \
  --query 'events[?startTime>`2025-09-29`]'

# Verify service health across regions
for region in us-east-1 us-west-2 eu-west-1; do
  echo "Checking $region"
  aws ec2 describe-instance-status \
    --region $region \
    --filters Name=instance-state-name,Values=running \
    --query 'InstanceStatuses[?InstanceStatus.Status!=`ok`]' \
    --output table
done
```

**Decision Point:** Is failover to secondary region required?
- **Yes:** Proceed to Phase 2
- **No:** Continue monitoring, prepare for potential failover

#### Phase 2: Failover Execution (15-60 minutes)

```bash
# 1. Update Route 53 health checks to mark primary unhealthy
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://failover-to-secondary.json

# 2. Promote read replicas to primary (RDS)
aws rds promote-read-replica \
  --db-instance-identifier prod-db-replica-us-west-2 \
  --backup-retention-period 35

# 3. Update application configuration
# Point applications to secondary region endpoints
# Update load balancer targets
# Verify cross-region connectivity

# 4. Scale up secondary region capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name prod-asg-us-west-2 \
  --desired-capacity 10  # Match primary capacity
```

#### Phase 3: Validation (60-90 minutes)

- [ ] DNS propagation complete (check from multiple locations)
- [ ] Application responding from secondary region
- [ ] Database connections successful
- [ ] No data loss beyond RPO
- [ ] User authentication working
- [ ] Monitoring and alerting functional

#### Phase 4: Failback (After primary region restored)

```bash
# 1. Verify primary region fully operational
# 2. Sync any data changes from secondary to primary
aws dms create-replication-task \
  --replication-task-identifier failback-sync-$(date +%Y%m%d) \
  --source-endpoint-arn <secondary-endpoint> \
  --target-endpoint-arn <primary-endpoint> \
  --migration-type full-load-and-cdc

# 3. Update Route 53 to fail back to primary
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://failback-to-primary.json

# 4. Scale down secondary region to normal capacity
# 5. Verify all services operational in primary
```

### Scenario 2: Data Corruption or Ransomware

**Indicators:**
- Unusual data modifications detected
- Files encrypted or deleted
- Application errors due to data inconsistency

**Response Procedure:**

#### Step 1: Immediate Containment

```bash
# 1. Enable S3 Object Lock (if not already)
aws s3api put-object-lock-configuration \
  --bucket critical-data \
  --object-lock-configuration '{"ObjectLockEnabled":"Enabled"}'

# 2. Enable MFA Delete
aws s3api put-bucket-versioning \
  --bucket critical-data \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::123456789012:mfa/admin MFA-CODE"

# 3. Revoke all access temporarily
aws s3api put-bucket-policy \
  --bucket critical-data \
  --policy file://deny-all-policy.json
```

#### Step 2: Assess Damage

```bash
# Identify last known good backup
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name production-vault \
  --by-resource-arn arn:aws:rds:us-east-1:123456789012:db:prod-database

# Check S3 versioning to find clean versions
aws s3api list-object-versions \
  --bucket critical-data \
  --prefix important-data/ \
  --max-items 100
```

#### Step 3: Restore from Clean Backup

```bash
# Restore RDS to point-in-time before corruption
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier prod-database \
  --target-db-instance-identifier prod-database-restored \
  --restore-time 2025-09-29T10:00:00Z  # Before corruption

# Restore S3 objects to previous versions
aws s3api restore-object \
  --bucket critical-data \
  --key important-file.dat \
  --version-id previous-version-id
```

### Scenario 3: Accidental Deletion of Critical Resources

**Indicators:**
- Production resources terminated or deleted
- User error or compromised credentials

**Response Procedure:**

```bash
# 1. Check CloudTrail for deletion events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteDBInstance \
  --max-results 50

# 2. Restore from most recent snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-database \
  --db-snapshot-identifier automated-snapshot-latest

# 3. For EC2 instances, launch from AMI
aws ec2 run-instances \
  --image-id ami-latest-prod \
  --instance-type t3.large \
  --subnet-id subnet-prod \
  --security-group-ids sg-prod \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=prod-restored}]'

# 4. Restore EBS volumes from snapshots
aws ec2 create-volume \
  --snapshot-id snap-1234567890abcdef0 \
  --availability-zone us-east-1a \
  --volume-type gp3

# 5. Implement additional safeguards
# - Enable termination protection
# - Add deletion lifecycle hooks
# - Require MFA for destructive operations
```

## DR Testing Schedule

### Annual Full DR Test

**Timing:** Q2 (April/May)  
**Duration:** Full weekend (Saturday-Sunday)  
**Scope:** Complete failover to DR region

**Success Criteria:**
- RTO met for all tier-1 services
- RPO met (data loss within acceptable limits)
- All critical business functions operational
- Automated failover mechanisms working
- Team response coordinated and effective

### Quarterly Component Tests

**Q1:** Database restore and failover  
**Q2:** Full DR test  
**Q3:** Application tier recovery  
**Q4:** Network and infrastructure recovery

## Recovery Checklists

### RDS Database Recovery

- [ ] Identify appropriate snapshot or point-in-time
- [ ] Restore to temporary instance for validation
- [ ] Verify data integrity and completeness
- [ ] Test application connectivity
- [ ] Update DNS or application configuration
- [ ] Promote to production
- [ ] Enable automated backups on restored instance
- [ ] Verify monitoring and alerting configured

### Application Tier Recovery

- [ ] Launch instances from latest AMI
- [ ] Attach appropriate IAM roles
- [ ] Mount EBS volumes (if needed)
- [ ] Configure application settings
- [ ] Register with load balancer
- [ ] Verify health checks passing
- [ ] Gradually increase traffic
- [ ] Monitor error rates and performance

### Network Recovery

- [ ] Verify VPC and subnet configuration
- [ ] Restore security groups and NACLs
- [ ] Re-establish VPN connections
- [ ] Configure routing tables
- [ ] Test connectivity between tiers
- [ ] Verify Transit Gateway attachments
- [ ] Enable VPC Flow Logs
- [ ] Update Route 53 records

## Communication Plan

### Internal Communication

**Stakeholders:**
- Executive team
- Engineering teams
- Customer support
- Sales team

**Channels:**
- Email: disaster-response@company.com
- Slack: #disaster-recovery
- Zoom: DR war room link
- SMS: For critical P1 incidents

**Update Frequency:**
- Every 30 minutes during active DR
- Hourly during recovery phase
- Final summary within 24 hours

### External Communication

**Status Page:** status.company.com

**Update Template:**
```
[Incident] - Service Disruption in Primary Region
Posted: 2025-09-29 14:30 UTC

We are experiencing issues with our primary infrastructure. 
We have activated our disaster recovery procedures and are 
failing over to our secondary region. We expect services to 
be fully restored within 4 hours.

Updates will be posted every 30 minutes.
```

## Post-DR Activities

### DR Report

**Required within 5 business days:**

1. **Executive Summary**
2. **Timeline of Events**
3. **RTO/RPO Achievement**
   - Target vs. Actual for each service
4. **Data Loss Assessment**
5. **Financial Impact**
6. **Lessons Learned**
7. **Improvement Actions**

### Improvement Backlog

Track all identified improvements:
- Technical: Infrastructure gaps
- Process: Procedure updates
- People: Training needs
- Documentation: Runbook updates

---

**Last Updated:** September 2025  
**Owner:** Operations Team  
**Review Schedule:** Quarterly  
**Next DR Test:** December 2025
