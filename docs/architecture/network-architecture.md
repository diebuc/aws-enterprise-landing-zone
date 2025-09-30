# Network Architecture

## Overview

This document describes the network architecture for the AWS Enterprise Landing Zone, implementing a hub-and-spoke topology with AWS Transit Gateway for centralized routing and network isolation.

## Network Design Principles

### 1. Segmentation and Isolation
- Production workloads isolated from development
- Application tiers separated by security groups and subnets
- No direct connectivity between untrusted zones

### 2. Centralized Management
- Single Transit Gateway as routing hub
- Centralized egress through NAT Gateways
- Unified network monitoring and logging

### 3. Scalability
- Design supports 50+ VPCs without topology changes
- CIDR allocation strategy accommodates growth
- Transit Gateway scales to 5,000 attachments

### 4. High Availability
- Multi-AZ deployment for all critical components
- Redundant NAT Gateways (one per AZ)
- Cross-AZ failover for databases and applications

### 5. Security by Design
- Private by default (no public IPs unless necessary)
- Defense in depth with multiple security layers
- Encrypted traffic where possible

---

## High-Level Topology

```
                        ┌─────────────────────────────┐
                        │   Shared Services VPC       │
                        │   (10.2.0.0/16)            │
                        │                             │
                        │   ┌─────────────────────┐  │
                        │   │  Transit Gateway    │  │
                        │   │  (Regional Hub)     │  │
                        │   └─────────┬───────────┘  │
                        └─────────────┼──────────────┘
                                      │
        ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
        ┃                             │                             ┃
┌───────▼─────────┐           ┌──────▼──────────┐         ┌───────▼─────────┐
│  Security VPC   │           │ Production VPC  │         │ Development VPC │
│  (10.1.0.0/16) │           │ (10.10.0.0/16) │         │ (10.30.0.0/16) │
│                 │           │                 │         │                 │
│ - GuardDuty     │           │ - Web Tier     │         │ - Test Env     │
│ - Security Hub  │           │ - App Tier     │         │ - Sandbox      │
│ - Config        │           │ - DB Tier      │         │                 │
└─────────────────┘           └─────────────────┘         └─────────────────┘
```

---

## IP Address Allocation

### CIDR Strategy

**Design Goal:** Non-overlapping address space supporting 100+ accounts

```
AWS Organization CIDR Space: 10.0.0.0/8

Core Accounts:
├── Management:        10.0.0.0/16   (Reserved, minimal use)
├── Security:          10.1.0.0/16   (Security services only)
├── Shared Services:   10.2.0.0/16   (Transit GW, DNS, shared infra)
└── Network:           10.3.0.0/16   (Reserved for network services)

Production Workloads:  10.10.0.0/12  (10.10.0.0 - 10.15.255.255)
├── Production-1:      10.10.0.0/16  (First prod workload)
├── Production-2:      10.11.0.0/16
├── Production-3:      10.12.0.0/16
└── ... (up to 16 production VPCs)

Staging Workloads:     10.20.0.0/12  (10.20.0.0 - 10.25.255.255)
├── Staging-1:         10.20.0.0/16
├── Staging-2:         10.21.0.0/16
└── ... (up to 16 staging VPCs)

Development Workloads: 10.30.0.0/12  (10.30.0.0 - 10.35.255.255)
├── Dev-1:             10.30.0.0/16
├── Dev-2:             10.31.0.0/16
└── ... (up to 16 dev VPCs)

Reserved for Growth:   10.40.0.0/12 - 10.255.0.0/12
```

### Subnet Allocation per VPC

**Standard VPC (/16) Breakdown:**

```
VPC: 10.X.0.0/16 (65,536 IPs)

Public Subnets:     10.X.0.0/20   (4,096 IPs per AZ)
├── AZ-A:          10.X.0.0/22   → 10.X.0.0 - 10.X.3.255
├── AZ-B:          10.X.4.0/22   → 10.X.4.0 - 10.X.7.255
└── AZ-C:          10.X.8.0/22   → 10.X.8.0 - 10.X.11.255

Private Subnets:    10.X.16.0/20  (4,096 IPs per AZ)
├── AZ-A:          10.X.16.0/22  → 10.X.16.0 - 10.X.19.255
├── AZ-B:          10.X.20.0/22  → 10.X.20.0 - 10.X.23.255
└── AZ-C:          10.X.24.0/22  → 10.X.24.0 - 10.X.27.255

Database Subnets:   10.X.32.0/20  (4,096 IPs per AZ)
├── AZ-A:          10.X.32.0/22  → 10.X.32.0 - 10.X.35.255
├── AZ-B:          10.X.36.0/22  → 10.X.36.0 - 10.X.39.255
└── AZ-C:          10.X.40.0/22  → 10.X.40.0 - 10.X.43.255

Transit Subnets:    10.X.48.0/20  (For TGW attachments)
├── AZ-A:          10.X.48.0/22  → 10.X.48.0 - 10.X.51.255
├── AZ-B:          10.X.52.0/22  → 10.X.52.0 - 10.X.55.255
└── AZ-C:          10.X.56.0/22  → 10.X.56.0 - 10.X.59.255

Reserved:           10.X.64.0/18  (Future expansion)
```

---

## Transit Gateway Architecture

### Why Transit Gateway?

**vs. VPC Peering:**
- **Scalability:** 5,000 attachments vs. 125 peering connections
- **Centralized routing:** Single route table vs. N×(N-1) configurations
- **Transitive routing:** Native support vs. not possible
- **Inspection points:** Allows centralized firewall vs. not possible
- **Operational complexity:** O(n) vs. O(n²) management overhead

**Trade-off:** Higher cost (~$36/attachment/month) but dramatically simpler operations

### Transit Gateway Configuration

**Settings:**
- **Amazon side ASN:** 64512 (private ASN)
- **Auto accept attachments:** Disabled (manual approval)
- **Default route table:** Enabled
- **DNS support:** Enabled
- **VPN ECMP support:** Enabled (for redundant VPN)
- **Multicast support:** Disabled

### Route Table Strategy

#### Production Route Table
**Attachments:**
- All production VPCs
- Shared Services VPC

**Routes:**
```
10.10.0.0/12    → Production VPCs (intra-production)
10.2.0.0/16     → Shared Services
0.0.0.0/0       → Inspection VPC (optional)
```

**Isolation:** Cannot reach development or staging

#### Non-Production Route Table
**Attachments:**
- Development VPCs
- Staging VPCs
- Shared Services VPC

**Routes:**
```
10.20.0.0/12    → Staging VPCs
10.30.0.0/12    → Development VPCs
10.2.0.0/16     → Shared Services
```

**Isolation:** Cannot reach production

#### Shared Services Route Table
**Attachments:**
- Shared Services VPC only

**Routes:**
```
10.0.0.0/8      → All VPCs (hub can reach all spokes)
```

### Traffic Flow Examples

**Production Web Server → Production Database:**
```
Web Server (10.10.1.10) 
  → Local route within VPC 
  → Database (10.10.32.10)
```

**Production App → Shared DNS:**
```
App Server (10.10.16.10)
  → VPC route table: 10.2.0.0/16 → Transit Gateway
  → TGW Production Route Table → Shared Services VPC
  → DNS Server (10.2.16.10)
```

**Development → Production (BLOCKED):**
```
Dev Instance (10.30.1.10)
  → VPC route table: 10.10.0.0/16 → Transit Gateway
  → TGW Dev Route Table → No route to 10.10.0.0/16
  → Traffic dropped ❌
```

---

## VPC Design Patterns

### Public Subnets
**Purpose:** Internet-facing resources

**Resources:**
- Application Load Balancers
- NAT Gateways
- Bastion hosts (if required)

**Routing:**
```
0.0.0.0/0       → Internet Gateway
10.0.0.0/8      → Transit Gateway (for cross-VPC)
Local           → VPC CIDR
```

**Security:**
- Restrictive security groups (port 80/443 only for ALB)
- No compute workloads (only load balancers)
- NACLs for additional protection

### Private Subnets
**Purpose:** Application tier, compute resources

**Resources:**
- EC2 instances
- ECS/EKS clusters
- Lambda functions (VPC mode)
- Application servers

**Routing:**
```
0.0.0.0/0       → NAT Gateway (outbound internet)
10.0.0.0/8      → Transit Gateway (cross-VPC)
Local           → VPC CIDR
```

**Security:**
- No public IP addresses
- Inbound only from public tier via security groups
- Outbound through NAT Gateway

### Database Subnets
**Purpose:** Data tier, highest security

**Resources:**
- RDS instances
- ElastiCache clusters
- Redshift clusters
- DynamoDB VPC endpoints

**Routing:**
```
10.0.0.0/8      → Transit Gateway (for cross-VPC DB access)
Local           → VPC CIDR
NO DEFAULT ROUTE (no internet access)
```

**Security:**
- Isolated from internet completely
- Inbound only from private tier
- Security group rules by source SG (not CIDR)
- Encryption at rest mandatory

---

## Internet Connectivity

### Ingress (Inbound from Internet)

**Path:**
```
Internet → Route 53 (DNS)
       → CloudFront (CDN, optional)
       → Application Load Balancer (public subnet)
       → Target Group (private subnet)
```

**Security Layers:**
1. **Route 53:** DDoS protection via AWS Shield
2. **CloudFront:** WAF rules, geo-blocking
3. **ALB:** SSL/TLS termination, target health checks
4. **Security Groups:** Port restrictions
5. **Application:** Input validation, authentication

### Egress (Outbound to Internet)

**NAT Gateway Strategy:**
- **Production:** 3 NAT Gateways (one per AZ) for high availability
- **Development:** 1 NAT Gateway (cost optimization)

**Path:**
```
Private Instance → NAT Gateway (public subnet)
                → Internet Gateway
                → Internet
```

**Cost Optimization:**
- VPC endpoints for AWS services (S3, DynamoDB) - no NAT charge
- Route 53 Resolver endpoints for on-premises DNS
- Interface endpoints for frequently used services

---

## Security Groups and NACLs

### Security Group Strategy

**Default Policy:** Deny all, explicitly allow required traffic

**Standard Security Groups:**

#### Web Tier SG
```
Inbound:
  - Port 80   from 0.0.0.0/0       (HTTP)
  - Port 443  from 0.0.0.0/0       (HTTPS)

Outbound:
  - All traffic to App Tier SG
  - Port 443 to 0.0.0.0/0          (API calls)
```

#### App Tier SG
```
Inbound:
  - Port 8080 from Web Tier SG     (Application)
  - Port 22   from Bastion SG      (SSH, if needed)

Outbound:
  - Port 3306 to DB Tier SG        (MySQL)
  - Port 5432 to DB Tier SG        (PostgreSQL)
  - Port 443  to 0.0.0.0/0         (AWS APIs)
```

#### DB Tier SG
```
Inbound:
  - Port 3306 from App Tier SG     (MySQL)
  - Port 5432 from App Tier SG     (PostgreSQL)

Outbound:
  - None (databases don't initiate outbound)
```

**Best Practices:**
- Reference by security group ID, not CIDR
- Principle of least privilege
- Regular audit via Access Analyzer
- Automatic alerts on changes

### Network ACL Strategy

**When to use NACLs:**
- Additional layer of defense
- Subnet-level protection
- Block known malicious IPs
- Compliance requirements

**Configuration:**
- Default allow (to avoid breaking existing flows)
- Explicit deny rules for known threats
- Stateless (must allow return traffic)

---

## VPC Endpoints

### Gateway Endpoints (Free)
- **S3:** For accessing S3 without NAT Gateway charges
- **DynamoDB:** For accessing DynamoDB privately

**Configuration:**
```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [
    aws_route_table.private[*].id,
    aws_route_table.database[0].id
  ]
}
```

### Interface Endpoints (Paid)
**For frequently used services:**
- EC2 (for API calls from instances)
- SSM (for Systems Manager)
- Secrets Manager
- ECR (for container images)
- CloudWatch Logs

**Cost vs. Benefit:**
- Interface endpoint: ~$7/month per endpoint
- NAT Gateway data processing: $0.045/GB
- Use interface endpoints if >155 GB/month per service

---

## Hybrid Connectivity

### VPN Connection (for development/testing)
- Site-to-Site VPN to Transit Gateway
- Redundant tunnels for HA
- BGP for dynamic routing

### Direct Connect (for production)
- Dedicated 1 Gbps or 10 Gbps connection
- Private Virtual Interface to Transit Gateway
- Backup VPN for failover

**Routing:**
```
On-premises: 192.168.0.0/16
  → Direct Connect → Transit Gateway
  → Production VPCs (via route table)
```

---

## DNS Architecture

### Route 53 Private Hosted Zones
- One per VPC or shared across VPCs
- Custom domain: `corp.internal`
- Associated with VPCs via API

**Example:**
```
prod-db.corp.internal      → 10.10.32.10 (RDS endpoint)
shared-dns.corp.internal   → 10.2.16.10  (Shared DNS server)
```

### Route 53 Resolver
- For hybrid DNS resolution
- Inbound endpoints: On-premises can query AWS
- Outbound endpoints: AWS can query on-premises

---

## Monitoring and Logging

### VPC Flow Logs
**Enabled for:**
- All VPCs
- All subnets
- All ENIs

**Destination:** CloudWatch Logs → S3 (after 30 days)

**Use Cases:**
- Security investigation
- Traffic analysis
- Compliance auditing

### Network Metrics
**CloudWatch Metrics:**
- NAT Gateway bytes processed
- Transit Gateway bytes sent/received
- VPC endpoint requests

**Alarms:**
- NAT Gateway bandwidth >80%
- Unusual traffic patterns
- Failed connection attempts

---

## Scalability Planning

### Current Capacity
- **VPCs:** 5 deployed, supports 100+
- **Subnets per VPC:** 12 (supports 50+)
- **Transit Gateway attachments:** 5 (supports 5,000)

### Growth Strategy
**0-12 months:**
- Add workload VPCs as needed (10.10.x.x range)
- Maintain current architecture

**12-24 months:**
- Consider multi-region for DR
- Evaluate Direct Connect for hybrid

**24+ months:**
- Transit Gateway peering to other regions
- Global network architecture

---

## Cost Optimization

### Current Monthly Costs (10 VPCs)

| Component | Cost |
|-----------|------|
| Transit Gateway (hub) | $36/month |
| TGW Attachments (10) | $360/month ($36 each) |
| NAT Gateways (6 total) | $270/month ($45 each) |
| NAT Data Processing | ~$50-100/month |
| VPC Endpoints (interface) | $42/month (6 endpoints) |
| **Total** | **~$758/month** |

### Optimization Strategies
1. **Use VPC endpoints** for high-traffic AWS services
2. **Single NAT Gateway** in dev/staging (not prod)
3. **VPC endpoint policies** to reduce data transfer
4. **S3 Gateway endpoint** (free) instead of NAT

---

**Last Updated:** September 2025  
**Owner:** Network Engineering Team  
**Review Schedule:** Quarterly
