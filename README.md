# AWS Enterprise Landing Zone

> **Production-ready multi-account AWS foundation with automated governance, security baseline, and operational excellence**

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Security Scan](https://img.shields.io/badge/Security-Validated-success?style=for-the-badge&logo=security&logoColor=white)](https://github.com/yourusername/aws-enterprise-landing-zone/actions)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

## 🎯 Overview

Enterprise-grade AWS Landing Zone implementing a **hub-and-spoke architecture** with centralized governance, security controls, and operational automation. Designed for organizations requiring **compliance** (SOC2, PCI-DSS, GDPR, HIPAA), **multi-account management**, and **cost optimization**.

### Key Features

- ✅ **Multi-Account Strategy** - AWS Organizations with Control Tower and automated account provisioning
- 🔐 **Security Baseline** - GuardDuty, Security Hub, Config, CloudTrail, and Access Analyzer across all accounts
- 🌐 **Hub-and-Spoke Networking** - Transit Gateway with centralized routing and network isolation
- 📊 **Centralized Logging** - Organization-wide log aggregation with CloudWatch and S3 lifecycle policies
- 💰 **Cost Optimization** - Automated cost analysis, budget alerts, and resource tagging enforcement
- 🛡️ **Service Control Policies** - Advanced SCPs for security, compliance, and cost governance
- 📋 **Operational Runbooks** - Comprehensive procedures for monitoring, incident response, and disaster recovery
- 🚀 **CI/CD Pipeline** - Automated validation, security scanning, and cost estimation

## 🏗️ Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                     Management Account                          │
│              (AWS Organizations + Control Tower)                │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼──────┐  ┌─────▼──────┐  ┌─────▼──────────┐
│   Security   │  │   Shared   │  │   Workloads    │
│   Account    │  │  Services  │  │   Accounts     │
│              │  │            │  │                │
│ - GuardDuty  │  │ - Transit  │  │ - Production   │
│ - Security   │  │   Gateway  │  │ - Staging      │
│   Hub        │  │ - Route 53 │  │ - Development  │
│ - Config     │  │ - Directory│  │                │
└──────────────┘  └────────────┘  └────────────────┘
```

### Network Architecture

**Hub-and-Spoke Model** with Transit Gateway:
- **Public Subnets**: Internet-facing load balancers and NAT Gateways
- **Private Subnets**: Application servers and compute resources
- **Database Subnets**: Isolated database tier with no internet access
- **Transit Subnets**: Dedicated subnets for Transit Gateway attachments

**Why Transit Gateway over VPC Peering?**
- Scales to 5,000+ VPC attachments vs. 125 peering connections
- Centralized routing eliminates N×(N-1) route table management
- Supports network inspection and centralized egress
- Enables transitive routing across all VPCs

## 💰 Cost Analysis

### Monthly Cost Breakdown

| Component | Small Org (5 accounts) | Medium Org (15 accounts) | Enterprise (50 accounts) |
|-----------|------------------------|--------------------------|--------------------------|
| **Control Tower** | $89 | $89 | $89 |
| **GuardDuty** | $78 | $234 | $780 |
| **AWS Config** | $117 | $351 | $1,170 |
| **Transit Gateway** | $145 | $290 | $580 |
| **CloudTrail** | $68 | $68 | $68 |
| **CloudWatch Logs** | $39 | $118 | $395 |
| **Security Hub** | $15 | $45 | $150 |
| **AWS Backup** | $25 | $75 | $250 |
| **Total (estimated)** | **$576/mo** | **$1,270/mo** | **$3,482/mo** |

**Cost Optimization Features:**
- Automated cost calculator with optimization recommendations
- S3 lifecycle policies (Glacier transitions after 90 days)
- Reserved Instance recommendations
- Log retention policies reduce storage by 40%
- Tag enforcement enables precise cost allocation

[Run cost calculator →](scripts/pre-deployment/cost-calculator.py)

## 🚀 Quick Start

### Prerequisites

- **AWS Account** with Organizations enabled
- **Terraform** >= 1.5.0
- **AWS CLI** configured with appropriate credentials
- **Python** 3.9+ (for automation scripts)

### Validation (No AWS Costs)

```bash
# Clone repository
git clone https://github.com/yourusername/aws-enterprise-landing-zone.git
cd aws-enterprise-landing-zone

# Validate Terraform configuration
cd terraform/global
terraform init
terraform validate
terraform plan

# Run security scanning
tfsec .
checkov -d .

# Estimate costs
python scripts/pre-deployment/cost-calculator.py \
  --accounts 10 \
  --employees 500 \
  --data-gb 1000
```

### Deployment

**⚠️ Warning:** This will create real AWS resources and incur costs. Review the [deployment guide](docs/deployment/step-by-step-guide.md) carefully.

```bash
# 1. Configure organization domain
export TF_VAR_organization_domain="yourcompany.com"

# 2. Initialize Terraform
terraform init

# 3. Review execution plan
terraform plan -out=landing-zone.tfplan

# 4. Deploy (requires approval)
terraform apply landing-zone.tfplan
```

**Deployment time:** 2-4 hours for complete setup

## 📁 Project Structure

```
aws-enterprise-landing-zone/
├── terraform/
│   ├── global/                    # AWS Organizations and Control Tower
│   ├── modules/
│   │   ├── account-baseline/      # Security baseline for all accounts
│   │   ├── networking/            # VPC, Transit Gateway, subnets
│   │   ├── logging/               # Centralized logging and monitoring
│   │   └── monitoring/            # CloudWatch dashboards and alarms
│   └── environments/              # Account-specific configurations
├── policies/
│   └── service-control-policies/  # SCPs for security and compliance
├── scripts/
│   ├── pre-deployment/            # Cost calculator, readiness checks
│   └── post-deployment/           # Health checks, compliance reports
├── docs/
│   ├── architecture/              # Architecture diagrams and decisions
│   ├── deployment/                # Step-by-step deployment guides
│   └── operations/                # Runbooks and procedures
└── .github/workflows/             # CI/CD pipelines
```

## 🔐 Security Features

### Service Control Policies (SCPs)

Three comprehensive policy sets enforce security and compliance:

#### 1. Security Baseline Policy
- ❌ Deny root account usage
- ❌ Prevent disabling security services (GuardDuty, Config, CloudTrail)
- ❌ Block unencrypted S3 uploads and EBS volumes
- ❌ Prevent public RDS instances
- ✅ Require MFA for sensitive operations

#### 2. Cost Control Policy
- 🌍 Restrict to approved regions (us-east-1, us-west-2, eu-west-1)
- 💻 Block expensive instance types (metal, GPU, x1/x2 families)
- 🏷️ Enforce cost allocation tags (CostCenter, Owner, Environment)
- 💾 Limit EBS volume sizes (<1TB without approval)

#### 3. Compliance Guardrails Policy
- 🇪🇺 GDPR: Data residency enforcement for PII
- 🔒 PCI-DSS: Encryption at rest and in transit
- 📅 SOX: 7-year backup retention
- 🔍 HIPAA: VPC endpoints for sensitive data access

[View complete SCP documentation →](docs/operations/security-policies.md)

### Automated Security Monitoring

- **GuardDuty:** Threat detection with ML-powered analysis
- **Security Hub:** Centralized security findings from 20+ services
- **AWS Config:** 50+ compliance rules with auto-remediation
- **CloudTrail:** Organization-wide audit logging with integrity validation
- **Access Analyzer:** Continuous permissions monitoring

**Mean Time to Detection (MTTD):** <15 minutes for critical threats

## 📊 Monitoring and Observability

### CloudWatch Dashboards

- **Security Operations Dashboard:** Real-time security metrics and findings
- **Cost Dashboard:** Daily spend tracking and anomaly detection
- **Infrastructure Health:** Resource utilization and performance metrics

### Metric Filters and Alarms

- Root account usage
- Unauthorized API calls
- IAM policy changes
- Security group modifications
- Network ACL changes
- Console sign-in failures

[View monitoring runbook →](docs/operations/monitoring-runbook.md)

## 🔄 Disaster Recovery

### Multi-Region Strategy

- **Primary Region:** us-east-1 (N. Virginia)
- **Secondary Region:** us-west-2 (Oregon) - Hot standby
- **DR Region:** eu-west-1 (Ireland) - Backup storage

### Recovery Objectives

| Service Tier | RTO | RPO | Availability |
|--------------|-----|-----|--------------|
| **Critical** (databases, auth) | 4 hours | 1 hour | 99.9% |
| **Important** (APIs, web) | 8 hours | 4 hours | 99.5% |
| **Standard** (internal tools) | 24 hours | 24 hours | 99.0% |

**Automated Backup:**
- RDS: Point-in-time recovery with 35-day retention
- EBS: Daily snapshots with cross-region replication
- S3: Real-time cross-region replication for critical data

[View DR runbook →](docs/operations/disaster-recovery.md)

## 🛠️ Operational Procedures

### Daily Health Checks

- Security posture review (GuardDuty, Security Hub)
- Cost and budget validation
- Service health monitoring
- Backup completion verification

### Incident Response

- **P1 (Critical):** 5-minute response - Active breach, data exfiltration
- **P2 (High):** 30-minute response - Privilege escalation, malware
- **P3 (Medium):** 2-hour response - Policy violations, suspicious activity
- **P4 (Low):** 24-hour response - Informational findings

[View incident response procedures →](docs/operations/incident-response.md)

## 📈 Success Metrics

### Technical KPIs

- ✅ **Security Posture:** 100% compliant resources
- ✅ **Availability:** 99.9% uptime for critical systems
- ✅ **Performance:** <2 second response time
- ✅ **Recovery:** RTO <4h, RPO <1h

### Business KPIs

- 💰 **Cost Optimization:** 20% infrastructure cost reduction
- 🚀 **Deployment Velocity:** 50% faster deployment cycles
- 📋 **Compliance:** 100% automated reporting
- ⚙️ **Operational Efficiency:** 60% reduction in manual tasks

### Security Metrics

- 🔍 **MTTD:** <15 minutes for critical threats
- ⚡ **MTTR:** <1 hour for security incidents
- 🎯 **Compliance Score:** >95% across all frameworks
- 🛡️ **Vulnerability Management:** 100% critical patches within 24 hours

## 🧪 Testing and Validation

### Automated Testing

GitHub Actions pipeline validates every commit:

- ✅ Terraform format and validation
- ✅ Security scanning (tfsec, Checkov, Semgrep)
- ✅ Cost estimation and optimization analysis
- ✅ Compliance policy validation

### Disaster Recovery Testing

- **Quarterly:** Component testing (databases, applications, network)
- **Annually:** Full failover to DR region
- **Documentation:** Comprehensive test results and lessons learned

## 📚 Documentation

### Architecture

- [High-Level Design](docs/architecture/high-level-design.md) - Complete architecture overview
- [Security Model](docs/architecture/security-model.md) - Security architecture and controls
- [Network Design](docs/architecture/network-architecture.md) - Detailed network topology

### Operations

- [Monitoring Runbook](docs/operations/monitoring-runbook.md) - Daily checks and alert response
- [Incident Response](docs/operations/incident-response.md) - Security incident procedures
- [Disaster Recovery](docs/operations/disaster-recovery.md) - DR procedures and testing
- [Security Policies](docs/operations/security-policies.md) - SCP documentation and testing

### Deployment

- [Step-by-Step Guide](docs/deployment/step-by-step-guide.md) - Complete deployment walkthrough
- [Prerequisites Checklist](docs/deployment/prerequisites.md) - Pre-deployment requirements
- [Troubleshooting](docs/deployment/troubleshooting.md) - Common issues and solutions

## 🎓 Professional Background

This Landing Zone reflects enterprise architecture patterns and operational best practices from experience with:

- Multi-account strategies for 100+ AWS accounts
- Regulatory compliance (SOC2, PCI-DSS, GDPR, HIPAA)
- Large-scale cloud migrations from on-premises
- 24/7 production operations with 99.9%+ uptime
- Cost optimization across petabyte-scale infrastructure

**Certifications:**
- AWS Certified Solutions Architect - Associate
- AWS Certified SysOps Administrator - Associate
- AWS Certified Developer - Associate
- AWS Certified Cloud Practitioner
- AWS Certified AI Practitioner

## 🤝 Contributing

This is a portfolio project demonstrating enterprise AWS architecture. For questions or discussions about the implementation:

- **LinkedIn:** [Profile](https://linkedin.com/in/diego-b-rey)
- **Email:** diebuc@gmail.com
- **Location:** Madrid, Spain 🇪🇸

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## ⚠️ Disclaimer

This project is designed for educational and portfolio purposes. While based on production-grade patterns, always:

- Review and adapt to your specific requirements
- Test thoroughly in non-production environments
- Consult AWS documentation and Well-Architected Framework
- Consider engaging AWS Professional Services for production deployments

---

<div align="center">

**Built with ❤️ for operational excellence and infrastructure automation**

[View on GitHub](https://github.com/diebuc/aws-enterprise-landing-zone) • [Report Issue](https://github.com/diebuc/aws-enterprise-landing-zone/issues)

</div>
