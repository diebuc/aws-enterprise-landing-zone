# Screenshot Placeholders

This directory will contain actual AWS Console screenshots for portfolio presentation.

## To Add Real Screenshots

### 1. Deploy Landing Zone (or use demo account)
```bash
cd terraform/global
terraform init
terraform plan
terraform apply
```

### 2. Capture Required Screenshots

#### CloudWatch Dashboard (`monitoring-cloudwatch-dashboard.png`)
- Navigate to: **CloudWatch → Dashboards**
- Select: `[organization-name]-landing-zone-overview`
- Take full-screen screenshot
- Resolution: 1920x1080 or higher

#### Security Hub (`security-hub-compliance-score.png`)
- Navigate to: **Security Hub → Summary**
- Show compliance score and findings count
- Ensure no sensitive data visible
- Crop to relevant section

#### Cost Explorer (`cost-explorer-service-breakdown.png`)
- Navigate to: **Cost Management → Cost Explorer**
- Select: Last 30 days
- Group by: Service
- Show top 5 services
- Screenshot the graph

#### Transit Gateway (`network-transit-gateway-routing.png`)
- Navigate to: **VPC → Transit Gateways**
- Select your TGW
- Go to: Route Tables tab
- Show routing configuration
- Blur account IDs if needed

#### AWS Organizations (`organizations-account-structure.png`)
- Navigate to: **AWS Organizations**
- Show OU structure
- Expand to show accounts
- Blur account IDs and names if needed

### 3. Image Guidelines

**Format:** PNG (preferred) or JPG
**Resolution:** Minimum 1920x1080
**Naming:** Use descriptive kebab-case names

**Redaction Required:**
- Account IDs (unless demo account)
- Email addresses
- Private URLs
- Actual cost amounts (if confidential)
- Team member names

**Tools:**
- macOS: Cmd+Shift+4 for selection
- Windows: Snipping Tool or Win+Shift+S
- Linux: GNOME Screenshot or Flameshot
- Chrome: Full Page Screen Capture extension

### 4. Add Screenshots to README

Once you have screenshots, update README.md:

```markdown
## 📸 Portfolio Showcase

### Live Monitoring
![CloudWatch Dashboard](docs/assets/screenshots/monitoring-cloudwatch-dashboard.png)

### Security Posture
![Security Hub](docs/assets/screenshots/security-hub-compliance-score.png)

### Network Architecture
![Transit Gateway](docs/assets/screenshots/network-transit-gateway-routing.png)

### Cost Tracking
![Cost Explorer](docs/assets/screenshots/cost-explorer-service-breakdown.png)
```

## Quick Screenshot Checklist

- [ ] CloudWatch Dashboard (security + cost)
- [ ] Security Hub compliance score
- [ ] GuardDuty findings (if any demo findings)
- [ ] AWS Config compliance rules
- [ ] Transit Gateway route tables
- [ ] VPC topology (Network Manager if available)
- [ ] Cost Explorer service breakdown
- [ ] AWS Organizations structure
- [ ] CloudTrail event history sample
- [ ] Budgets configuration

## Alternative: Use Demo Account

If you don't want to deploy to your AWS account:

1. **AWS Free Tier Account**: Create a new account for demo purposes
2. **LocalStack**: Simulate AWS services locally (limited screenshot value)
3. **Mock Screenshots**: Create clean UI mockups (less authentic)
4. **Sample Data**: Use AWS documentation screenshots with attribution

## Current Status

🟡 **Placeholder files only** - No actual screenshots yet

Once screenshots are added, this file can be removed.

## Notes

- This is for portfolio presentation only
- Screenshots should show functioning infrastructure
- Consider privacy and company policies
- Mark as "Demo Environment" if needed
