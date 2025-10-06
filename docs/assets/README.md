# Assets Directory

Visual assets for AWS Landing Zone documentation and portfolio presentation.

## Directory Structure

```
docs/assets/
├── screenshots/           # AWS Console screenshots
│   ├── dashboard-*.png   # CloudWatch dashboards
│   ├── security-*.png    # Security Hub, GuardDuty
│   ├── network-*.png     # VPC, Transit Gateway
│   └── cost-*.png        # Cost Explorer, Budgets
├── diagrams/             # Architecture diagrams (exported)
│   ├── architecture-*.png
│   ├── network-*.png
│   └── security-*.png
└── logos/                # AWS service icons
    └── aws-icons/
```

## Screenshot Guidelines

### Required Screenshots for Portfolio

1. **Architecture Overview**
   - AWS Organizations console showing account structure
   - Control Tower dashboard with enabled guardrails
   - SCPs applied to organizational units

2. **Security Posture**
   - Security Hub compliance score dashboard
   - GuardDuty findings (sample/demo)
   - AWS Config compliance dashboard
   - CloudTrail event history

3. **Network Architecture**
   - Transit Gateway route tables
   - VPC topology (hub-and-spoke visualization)
   - Network Flow Logs configuration
   - VPC Endpoints list

4. **Cost Management**
   - Cost Explorer with service breakdown
   - AWS Budgets configuration
   - Cost anomaly detection alerts
   - CloudWatch cost dashboard

5. **Monitoring & Operations**
   - CloudWatch dashboards (security + cost)
   - SNS topics and subscriptions
   - CloudWatch Alarms configured
   - Log Insights queries

### Screenshot Best Practices

1. **Resolution**: Minimum 1920x1080, save as PNG
2. **Redaction**: Remove/blur any sensitive data:
   - Account IDs (unless demo account)
   - Email addresses
   - Internal URLs
   - Cost amounts (if confidential)

3. **Naming Convention**:
   ```
   [category]-[resource]-[view].png
   
   Examples:
   security-hub-compliance-score.png
   network-transit-gateway-routing.png
   cost-explorer-service-breakdown.png
   monitoring-cloudwatch-dashboard.png
   ```

4. **Annotations**: Add arrows/boxes to highlight key features
5. **Context**: Include timestamps showing recent activity

## Diagram Export Instructions

### Exporting Mermaid Diagrams

#### Method 1: GitHub (Automatic Rendering)
Mermaid diagrams in markdown files are automatically rendered on GitHub. To capture:
1. View the diagram on GitHub
2. Take screenshot or use browser dev tools
3. Crop to diagram only

#### Method 2: Mermaid Live Editor
1. Go to https://mermaid.live/
2. Paste diagram code
3. Click "Download PNG" or "Download SVG"
4. Save to `diagrams/` folder

#### Method 3: VS Code Extension
1. Install "Markdown Preview Mermaid Support" extension
2. Preview markdown file
3. Right-click diagram → "Copy Image"
4. Paste into image editor

### Architecture Diagrams

Export high-resolution versions of:
- `docs/architecture/diagrams/high-level-architecture.md`
- `docs/architecture/diagrams/network-topology.md`

Save as:
- `architecture-high-level.png` (2000px wide)
- `network-hub-spoke-topology.png` (2000px wide)
- `security-architecture.png` (2000px wide)

## AWS Architecture Icons

Download official AWS Architecture Icons:
https://aws.amazon.com/architecture/icons/

Useful for creating custom diagrams in:
- draw.io (diagrams.net)
- Lucidchart
- Microsoft Visio

## Portfolio Presentation

### Recommended Visuals for README

Add to main README.md:
```markdown
## Architecture Overview
![High Level Architecture](docs/assets/diagrams/architecture-high-level.png)

## Network Topology
![Hub and Spoke Network](docs/assets/diagrams/network-hub-spoke-topology.png)

## Security Dashboard
![Security Hub Compliance](docs/assets/screenshots/security-hub-compliance-score.png)

## Cost Monitoring
![Cost Dashboard](docs/assets/screenshots/monitoring-cloudwatch-cost-dashboard.png)
```

### GitHub Pages Site (Optional)

Create a `docs/index.html` for GitHub Pages:
- Interactive portfolio site
- Embed architecture diagrams
- Link to live demo (if available)
- Showcase certifications

## Demo Account Screenshots

For portfolio purposes, consider:
1. Creating screenshots from AWS Free Tier account
2. Using sample/demo data (no real company info)
3. Showing configured resources without actual costs
4. Including "Demo Environment" watermark

## Accessibility

- Add descriptive alt text to all images
- Ensure diagrams have high contrast
- Include text descriptions of complex visuals
- Test visibility on different screen sizes

## Tools Recommendations

- **Screenshots**: Snagit, Greenshot, macOS Screenshot
- **Annotations**: Skitch, Snagit, Preview (macOS)
- **Diagrams**: Mermaid Live, draw.io, Lucidchart
- **Optimization**: TinyPNG, ImageOptim (reduce file size)

## Version Control

- Add large binaries to `.gitignore` if >1MB
- Use Git LFS for large diagram files
- Keep original high-res versions locally
- Commit optimized versions to repo

## Copyright and Attribution

- AWS Architecture Icons: © Amazon Web Services
- Screenshots: Your own AWS accounts only
- Third-party diagrams: Obtain permission
- Mark as "Educational/Portfolio Use"
