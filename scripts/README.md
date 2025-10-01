# Scripts Directory

Automation scripts for Landing Zone deployment, validation, and operations.

## Pre-Deployment Scripts

### Cost Calculator
```bash
python scripts/pre-deployment/cost-calculator.py \
  --accounts 10 \
  --employees 500 \
  --data-gb 1000
```

Estimates monthly AWS costs based on:
- Number of accounts
- Employee count (for IAM users/roles)
- Data volume (for logging and backup)

## Post-Deployment Scripts

### Health Check
```bash
bash scripts/post-deployment/health-check.sh
```

Validates:
- ✓ AWS Organizations structure
- ✓ Control Tower baseline
- ✓ Security services (GuardDuty, Security Hub, Config)
- ✓ Networking (Transit Gateway, VPCs)
- ✓ Logging and monitoring

Exit codes:
- 0: All checks passed
- 1: Critical failures detected
- 2: Script execution error

### Compliance Report
```bash
python scripts/post-deployment/compliance-report.py
```

Generates compliance audit:
- AWS Config compliance scores per account
- Security Hub findings breakdown
- GuardDuty threat detection status
- Organization-wide compliance summary

**Run in CI/CD:** Both scripts return appropriate exit codes for pipeline integration.

## Requirements

```bash
# Python dependencies
pip install boto3

# AWS CLI
aws configure

# Required IAM permissions:
# - organizations:List*
# - config:Describe*
# - securityhub:GetFindings
# - guardduty:List*
# - ec2:Describe*
# - cloudwatch:GetMetric*
```

## Best Practices

1. **Run health checks after any infrastructure change**
2. **Schedule compliance reports weekly**
3. **Store reports in S3 for audit trail**
4. **Alert on compliance score drops below 90%**

## Troubleshooting

**Issue:** "AccessDenied" errors
- Ensure AWS credentials are configured
- Verify IAM role has required permissions
- Check you're in the management account

**Issue:** "No detectors found" in GuardDuty
- GuardDuty may not be enabled in all regions
- Verify service is active in expected regions

**Issue:** Slow execution
- Scripts query multiple accounts/services
- Expected runtime: 2-5 minutes for 10 accounts
- Consider parallel execution for 50+ accounts

## Automation Examples

### Weekly Compliance Report (Cron)
```bash
# Run every Monday at 9 AM
0 9 * * 1 cd /path/to/repo && python scripts/post-deployment/compliance-report.py > /var/log/compliance-$(date +\%Y\%m\%d).log
```

### CI/CD Integration (GitHub Actions)
```yaml
- name: Run Landing Zone Health Check
  run: |
    bash scripts/post-deployment/health-check.sh
    python scripts/post-deployment/compliance-report.py
```

### Alert on Failures (CloudWatch Events)
```bash
# Send SNS notification if compliance fails
python scripts/post-deployment/compliance-report.py || \
  aws sns publish --topic-arn arn:aws:sns:us-east-1:123456789012:compliance-alerts \
  --message "Compliance check failed. Review required."
```
