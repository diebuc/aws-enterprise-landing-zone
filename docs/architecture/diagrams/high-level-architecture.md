# AWS Enterprise Landing Zone - High Level Architecture

## Overview Architecture Diagram

```mermaid
graph TB
    subgraph "Management Account"
        Org[AWS Organizations]
        CT[Control Tower]
        Billing[Consolidated Billing]
        SCPs[Service Control Policies]
    end

    subgraph "Security Account"
        GD[GuardDuty<br/>Threat Detection]
        SH[Security Hub<br/>Centralized Findings]
        Config[AWS Config<br/>Compliance Rules]
        Trail[CloudTrail<br/>Audit Logs]
        Analyzer[Access Analyzer]
    end

    subgraph "Shared Services Account"
        TGW[Transit Gateway<br/>Network Hub]
        R53[Route 53<br/>Private DNS]
        Directory[Directory Service<br/>AD Integration]
        VPCEndpoints[VPC Endpoints<br/>PrivateLink]
    end

    subgraph "Log Archive Account"
        S3Logs[S3 Bucket<br/>Centralized Logs]
        Lifecycle[S3 Lifecycle<br/>Glacier Archive]
        Replication[Cross-Region<br/>Replication]
    end

    subgraph "Workload Accounts"
        Prod[Production VPC<br/>10.1.0.0/16]
        Stage[Staging VPC<br/>10.2.0.0/16]
        Dev[Development VPC<br/>10.3.0.0/16]
    end

    Org --> Security
    Org --> SharedServices
    Org --> LogArchive
    Org --> Workload

    Security --> GD
    Security --> SH
    Security --> Config
    Security --> Trail
    Security --> Analyzer

    SharedServices --> TGW
    SharedServices --> R53
    SharedServices --> Directory
    SharedServices --> VPCEndpoints

    TGW -.->|Routing| Prod
    TGW -.->|Routing| Stage
    TGW -.->|Routing| Dev

    Trail -.->|Logs| S3Logs
    Config -.->|Logs| S3Logs
    GD -.->|Findings| SH

    style Org fill:#FF9900
    style CT fill:#FF9900
    style GD fill:#DD344C
    style SH fill:#DD344C
    style Config fill:#DD344C
    style TGW fill:#4B612C
    style S3Logs fill:#569A31
```

## Account Structure

```mermaid
graph LR
    Root[Root OU] --> Security[Security OU]
    Root --> Infrastructure[Infrastructure OU]
    Root --> Workloads[Workloads OU]
    Root --> Sandbox[Sandbox OU]
    
    Security --> SecAccount[Security Account]
    Security --> LogAccount[Log Archive Account]
    Security --> AuditAccount[Audit Account]
    
    Infrastructure --> SharedServices[Shared Services]
    Infrastructure --> Network[Network Hub]
    
    Workloads --> ProdOU[Production OU]
    Workloads --> NonProdOU[Non-Production OU]
    
    ProdOU --> ProdApp1[App1-Prod]
    ProdOU --> ProdApp2[App2-Prod]
    
    NonProdOU --> Staging[Staging]
    NonProdOU --> Development[Development]
    
    Sandbox --> SandboxDev1[Dev Sandbox 1]
    Sandbox --> SandboxDev2[Dev Sandbox 2]

    style Root fill:#FF9900
    style Security fill:#DD344C
    style Infrastructure fill:#4B612C
    style Workloads fill:#527FFF
    style Sandbox fill:#FFB366
```

## Security Controls Flow

```mermaid
sequenceDiagram
    participant User
    participant IAM
    participant SCP
    participant Resource
    participant CloudTrail
    participant GuardDuty
    participant SecurityHub
    
    User->>IAM: Authenticate (MFA)
    IAM->>SCP: Check Service Control Policy
    SCP-->>IAM: Policy Evaluation
    IAM->>Resource: Authorize Action
    Resource->>CloudTrail: Log API Call
    CloudTrail->>GuardDuty: Stream Events
    GuardDuty->>SecurityHub: Send Findings
    SecurityHub->>SecurityHub: Aggregate & Correlate
    SecurityHub-->>User: Alert if Threat Detected
```

## Data Flow - Centralized Logging

```mermaid
graph LR
    subgraph "Source Accounts"
        CT1[CloudTrail]
        CW1[CloudWatch Logs]
        VPC1[VPC Flow Logs]
        Config1[Config Snapshots]
    end
    
    subgraph "Log Archive Account"
        S3[S3 Central Bucket]
        KMS[KMS Encryption]
        Glacier[Glacier Archive]
    end
    
    subgraph "Monitoring"
        Athena[Athena Queries]
        Dashboard[CloudWatch Dashboards]
        Alerts[SNS Alerts]
    end
    
    CT1 -->|Stream| S3
    CW1 -->|Export| S3
    VPC1 -->|Publish| S3
    Config1 -->|Snapshot| S3
    
    S3 --> KMS
    S3 -->|90 days| Glacier
    
    S3 --> Athena
    S3 --> Dashboard
    Athena --> Alerts

    style S3 fill:#569A31
    style KMS fill:#DD344C
    style Glacier fill:#569A31
```

## Network Traffic Flow

```mermaid
graph TB
    Internet[Internet]
    IGW[Internet Gateway]
    
    subgraph "Shared Services VPC"
        NATGateway[NAT Gateway<br/>Public Subnet]
        TGW_SS[Transit Gateway<br/>Attachment]
    end
    
    subgraph "Production VPC"
        ALB[Application<br/>Load Balancer]
        AppServers[Application<br/>Servers]
        Database[(RDS Database)]
        TGW_Prod[Transit Gateway<br/>Attachment]
    end
    
    subgraph "Staging VPC"
        AppStage[Application<br/>Servers]
        TGW_Stage[Transit Gateway<br/>Attachment]
    end
    
    Internet --> IGW
    IGW --> ALB
    ALB --> AppServers
    AppServers --> Database
    
    AppServers --> TGW_Prod
    TGW_Prod --> TGW_SS
    TGW_SS --> NATGateway
    NATGateway --> Internet
    
    TGW_Prod -.->|Private Routing| TGW_Stage
    AppStage --> TGW_Stage

    style ALB fill:#FF9900
    style Database fill:#527FFF
    style TGW_SS fill:#4B612C
    style TGW_Prod fill:#4B612C
    style TGW_Stage fill:#4B612C
```

## Disaster Recovery Architecture

```mermaid
graph TB
    subgraph "Primary Region - us-east-1"
        Primary_VPC[Production VPC]
        Primary_RDS[(RDS Primary)]
        Primary_S3[S3 Bucket]
        Primary_TGW[Transit Gateway]
    end
    
    subgraph "DR Region - us-west-2"
        DR_VPC[DR VPC]
        DR_RDS[(RDS Read Replica)]
        DR_S3[S3 Bucket]
        DR_TGW[Transit Gateway]
    end
    
    Primary_RDS -->|Async Replication| DR_RDS
    Primary_S3 -->|Cross-Region Replication| DR_S3
    Primary_VPC -.->|VPN/Peering| DR_VPC
    
    Primary_TGW -.->|TGW Peering| DR_TGW
    
    Primary_RDS -->|Daily Snapshots| Snapshots[Automated Snapshots]
    Snapshots -->|Copy| DR_Snapshots[DR Snapshots]

    style Primary_RDS fill:#527FFF
    style DR_RDS fill:#527FFF
    style Primary_S3 fill:#569A31
    style DR_S3 fill:#569A31
```

## Cost Monitoring Architecture

```mermaid
graph LR
    subgraph "Data Sources"
        CUR[Cost & Usage Reports]
        Budgets[AWS Budgets]
        CE[Cost Explorer API]
    end
    
    subgraph "Processing"
        Lambda[Lambda Functions]
        Athena[Athena Queries]
    end
    
    subgraph "Storage"
        S3Cost[S3 Cost Data]
        DynamoDB[DynamoDB Cache]
    end
    
    subgraph "Visualization"
        Dashboard[CloudWatch Dashboard]
        QuickSight[QuickSight Reports]
        SNS[SNS Alerts]
    end
    
    CUR --> S3Cost
    Budgets --> Lambda
    CE --> Lambda
    
    S3Cost --> Athena
    Lambda --> DynamoDB
    
    Athena --> Dashboard
    DynamoDB --> Dashboard
    Lambda --> SNS
    Dashboard --> QuickSight

    style Dashboard fill:#FF9900
    style SNS fill:#DD344C
```

## Legend

| Color | Purpose |
|-------|---------|
| 🟠 Orange | Management/Core AWS Services |
| 🔴 Red | Security Services |
| 🟢 Green | Storage/Data Services |
| 🔵 Blue | Compute/Database Services |
| 🟤 Brown | Networking Services |

## Architecture Principles

### Multi-Account Strategy
- **Isolation**: Each workload in separate account
- **Blast Radius**: Limits security incidents
- **Billing**: Clear cost allocation per team/project

### Hub-and-Spoke Network
- **Centralized Routing**: Single point of egress
- **Scalability**: Easy to add new VPCs
- **Security**: Inspection at central hub

### Security Layers
- **Preventive**: SCPs, IAM policies, NACLs
- **Detective**: GuardDuty, Config, CloudTrail
- **Responsive**: Automated remediation, alerts

### Operational Excellence
- **Automation**: Infrastructure as Code
- **Monitoring**: Centralized observability
- **Documentation**: Living architecture docs
