# Network Architecture - Detailed Topology

## Hub-and-Spoke Transit Gateway Architecture

```mermaid
graph TB
    Internet[Internet]
    
    subgraph "Shared Services VPC - Hub"
        subgraph "Public Subnets - 10.0.0.0/24"
            NAT1[NAT Gateway<br/>10.0.0.10<br/>AZ-1a]
            NAT2[NAT Gateway<br/>10.0.0.74<br/>AZ-1b]
            IGW[Internet Gateway]
        end
        
        subgraph "Transit Subnets - 10.0.1.0/24"
            TGW_ENI1[TGW ENI<br/>10.0.1.10]
            TGW_ENI2[TGW ENI<br/>10.0.1.74]
        end
        
        subgraph "Private Subnets - 10.0.2.0/23"
            SharedSvc1[Shared Services<br/>10.0.2.0/24]
            SharedSvc2[Shared Services<br/>10.0.3.0/24]
        end
        
        TGW_Hub[Transit Gateway<br/>Central Hub]
    end
    
    subgraph "Production VPC - 10.1.0.0/16"
        subgraph "Public Subnets"
            ALB_Prod[ALB<br/>10.1.0.0/24]
        end
        subgraph "Private Subnets"
            App_Prod[App Servers<br/>10.1.1.0/24]
        end
        subgraph "Database Subnets"
            DB_Prod[(RDS<br/>10.1.2.0/24)]
        end
        TGW_Prod[TGW Attachment]
    end
    
    subgraph "Staging VPC - 10.2.0.0/16"
        subgraph "Private Subnets"
            App_Stage[App Servers<br/>10.2.1.0/24]
        end
        subgraph "Database Subnets"
            DB_Stage[(RDS<br/>10.2.2.0/24)]
        end
        TGW_Stage[TGW Attachment]
    end
    
    subgraph "Development VPC - 10.3.0.0/16"
        subgraph "Private Subnets"
            App_Dev[App Servers<br/>10.3.1.0/24]
        end
        subgraph "Database Subnets"
            DB_Dev[(RDS<br/>10.3.2.0/24)]
        end
        TGW_Dev[TGW Attachment]
    end
    
    Internet <--> IGW
    IGW <--> NAT1
    IGW <--> NAT2
    
    NAT1 --> TGW_ENI1
    NAT2 --> TGW_ENI2
    TGW_ENI1 --> TGW_Hub
    TGW_ENI2 --> TGW_Hub
    
    TGW_Hub <--> TGW_Prod
    TGW_Hub <--> TGW_Stage
    TGW_Hub <--> TGW_Dev
    
    TGW_Prod --> App_Prod
    App_Prod --> DB_Prod
    
    TGW_Stage --> App_Stage
    App_Stage --> DB_Stage
    
    TGW_Dev --> App_Dev
    App_Dev --> DB_Dev
    
    ALB_Prod --> App_Prod

    style TGW_Hub fill:#4B612C
    style NAT1 fill:#FF9900
    style NAT2 fill:#FF9900
    style DB_Prod fill:#527FFF
    style DB_Stage fill:#527FFF
    style DB_Dev fill:#527FFF
```

## 3-Tier VPC Architecture (Production Example)

```mermaid
graph TB
    Users[Internet Users]
    
    subgraph "Availability Zone 1a"
        subgraph "Public Subnet - 10.1.0.0/25"
            ALB1[Application<br/>Load Balancer]
            NAT_1a[NAT Gateway]
        end
        
        subgraph "Private Subnet - 10.1.1.0/25"
            Web1[Web Server<br/>10.1.1.10]
            App1[App Server<br/>10.1.1.20]
        end
        
        subgraph "Database Subnet - 10.1.2.0/25"
            DB1[(RDS Primary<br/>10.1.2.10)]
        end
    end
    
    subgraph "Availability Zone 1b"
        subgraph "Public Subnet - 10.1.0.128/25"
            ALB2[Application<br/>Load Balancer]
            NAT_1b[NAT Gateway]
        end
        
        subgraph "Private Subnet - 10.1.1.128/25"
            Web2[Web Server<br/>10.1.1.138]
            App2[App Server<br/>10.1.1.148]
        end
        
        subgraph "Database Subnet - 10.1.2.128/25"
            DB2[(RDS Standby<br/>10.1.2.138)]
        end
    end
    
    Users --> ALB1
    Users --> ALB2
    
    ALB1 --> Web1
    ALB2 --> Web2
    
    Web1 --> App1
    Web2 --> App2
    
    App1 --> DB1
    App2 --> DB1
    
    DB1 -.->|Sync Replication| DB2
    
    Web1 -.->|Internet Access| NAT_1a
    Web2 -.->|Internet Access| NAT_1b
    App1 -.->|Internet Access| NAT_1a
    App2 -.->|Internet Access| NAT_1b

    style ALB1 fill:#FF9900
    style ALB2 fill:#FF9900
    style DB1 fill:#527FFF
    style DB2 fill:#527FFF
    style NAT_1a fill:#FF9900
    style NAT_1b fill:#FF9900
```

## Security Groups and NACLs

```mermaid
graph LR
    Internet[Internet]
    
    subgraph "Public Subnet NACL"
        NACL_Pub[Inbound: 80,443<br/>Outbound: All]
    end
    
    subgraph "ALB Security Group"
        SG_ALB[Inbound: 80,443<br/>from 0.0.0.0/0<br/>Outbound: 8080<br/>to App SG]
    end
    
    subgraph "Private Subnet NACL"
        NACL_Priv[Inbound: 8080<br/>Outbound: All]
    end
    
    subgraph "App Security Group"
        SG_App[Inbound: 8080<br/>from ALB SG<br/>Outbound: 3306<br/>to DB SG]
    end
    
    subgraph "Database Subnet NACL"
        NACL_DB[Inbound: 3306<br/>Outbound: Ephemeral]
    end
    
    subgraph "Database Security Group"
        SG_DB[Inbound: 3306<br/>from App SG<br/>Outbound: None]
    end
    
    Internet --> NACL_Pub
    NACL_Pub --> SG_ALB
    SG_ALB --> NACL_Priv
    NACL_Priv --> SG_App
    SG_App --> NACL_DB
    NACL_DB --> SG_DB

    style NACL_Pub fill:#DD344C
    style NACL_Priv fill:#DD344C
    style NACL_DB fill:#DD344C
    style SG_ALB fill:#FF9900
    style SG_App fill:#FF9900
    style SG_DB fill:#527FFF
```

## VPC Endpoints Architecture

```mermaid
graph TB
    subgraph "Production VPC"
        App[Application Servers]
        
        subgraph "Interface Endpoints"
            EP_EC2[com.amazonaws.us-east-1.ec2]
            EP_ECR[com.amazonaws.us-east-1.ecr.api]
            EP_Secrets[com.amazonaws.us-east-1.secretsmanager]
            EP_SSM[com.amazonaws.us-east-1.ssm]
        end
        
        subgraph "Gateway Endpoints"
            EP_S3[com.amazonaws.us-east-1.s3]
            EP_DynamoDB[com.amazonaws.us-east-1.dynamodb]
        end
    end
    
    subgraph "AWS Services"
        EC2_Service[EC2 Service]
        ECR_Service[ECR Service]
        Secrets_Service[Secrets Manager]
        SSM_Service[Systems Manager]
        S3_Service[S3 Service]
        DDB_Service[DynamoDB Service]
    end
    
    App -.->|Private| EP_EC2
    App -.->|Private| EP_ECR
    App -.->|Private| EP_Secrets
    App -.->|Private| EP_SSM
    App -.->|Private| EP_S3
    App -.->|Private| EP_DynamoDB
    
    EP_EC2 -.-> EC2_Service
    EP_ECR -.-> ECR_Service
    EP_Secrets -.-> Secrets_Service
    EP_SSM -.-> SSM_Service
    EP_S3 -.-> S3_Service
    EP_DynamoDB -.-> DDB_Service

    style App fill:#527FFF
    style EP_S3 fill:#569A31
    style EP_DynamoDB fill:#527FFF
```

## Transit Gateway Routing Tables

```mermaid
graph TB
    subgraph "Transit Gateway Route Tables"
        subgraph "Shared Services RT"
            RT_Hub[Destination: 10.1.0.0/16 → Prod Attachment<br/>Destination: 10.2.0.0/16 → Stage Attachment<br/>Destination: 10.3.0.0/16 → Dev Attachment<br/>Destination: 0.0.0.0/0 → Shared VPC]
        end
        
        subgraph "Production RT"
            RT_Prod[Destination: 10.0.0.0/16 → Shared Attachment<br/>Destination: 0.0.0.0/0 → Shared Attachment<br/>Blackhole: 10.2.0.0/16, 10.3.0.0/16]
        end
        
        subgraph "Non-Production RT"
            RT_NonProd[Destination: 10.0.0.0/16 → Shared Attachment<br/>Destination: 10.2.0.0/16 → Stage Attachment<br/>Destination: 10.3.0.0/16 → Dev Attachment<br/>Destination: 0.0.0.0/0 → Shared Attachment<br/>Blackhole: 10.1.0.0/16]
        end
    end

    style RT_Hub fill:#4B612C
    style RT_Prod fill:#DD344C
    style RT_NonProd fill:#527FFF
```

## Network Flow Logs Architecture

```mermaid
graph LR
    subgraph "VPCs"
        VPC1[Production VPC]
        VPC2[Staging VPC]
        VPC3[Development VPC]
    end
    
    subgraph "Flow Logs"
        FL1[VPC Flow Logs]
        FL2[Subnet Flow Logs]
        FL3[ENI Flow Logs]
    end
    
    subgraph "Destinations"
        CW[CloudWatch Logs]
        S3[S3 Bucket]
    end
    
    subgraph "Analysis"
        Athena[Athena Queries]
        Dashboard[CloudWatch Insights]
    end
    
    VPC1 --> FL1
    VPC2 --> FL2
    VPC3 --> FL3
    
    FL1 --> CW
    FL2 --> CW
    FL3 --> S3
    
    CW --> Dashboard
    S3 --> Athena

    style S3 fill:#569A31
    style CW fill:#FF9900
```

## IP Address Allocation Strategy

| VPC | CIDR Block | Subnets | Purpose |
|-----|------------|---------|---------|
| **Shared Services** | 10.0.0.0/16 | 65,536 IPs | Transit Gateway Hub |
| - Public | 10.0.0.0/24 | 256 IPs | NAT Gateways, Bastion |
| - Transit | 10.0.1.0/24 | 256 IPs | TGW ENIs |
| - Private | 10.0.2.0/23 | 512 IPs | Shared services |
| **Production** | 10.1.0.0/16 | 65,536 IPs | Production workloads |
| - Public | 10.1.0.0/24 | 256 IPs | Load balancers |
| - Private | 10.1.1.0/24 | 256 IPs | Application tier |
| - Database | 10.1.2.0/24 | 256 IPs | Database tier |
| **Staging** | 10.2.0.0/16 | 65,536 IPs | Pre-production testing |
| - Private | 10.2.1.0/24 | 256 IPs | Application tier |
| - Database | 10.2.2.0/24 | 256 IPs | Database tier |
| **Development** | 10.3.0.0/16 | 65,536 IPs | Development environment |
| - Private | 10.3.1.0/24 | 256 IPs | Application tier |
| - Database | 10.3.2.0/24 | 256 IPs | Database tier |

## DNS Architecture

```mermaid
graph TB
    subgraph "Route 53"
        PublicZone[Public Hosted Zone<br/>example.com]
        PrivateZone[Private Hosted Zone<br/>internal.example.com]
    end
    
    subgraph "VPCs"
        Prod[Production VPC]
        Stage[Staging VPC]
        Dev[Development VPC]
    end
    
    subgraph "Endpoints"
        ALB[api.example.com<br/>→ ALB]
        RDS[db.internal.example.com<br/>→ RDS Endpoint]
        EC2[app.internal.example.com<br/>→ EC2 Instances]
    end
    
    Internet[Internet] --> PublicZone
    PublicZone --> ALB
    
    PrivateZone --> Prod
    PrivateZone --> Stage
    PrivateZone --> Dev
    
    Prod --> RDS
    Prod --> EC2

    style PublicZone fill:#FF9900
    style PrivateZone fill:#569A31
```

## Network Best Practices Implemented

### Segmentation
- ✅ Separate VPCs per environment (Prod/Stage/Dev)
- ✅ Separate subnets per tier (Public/Private/Database)
- ✅ Separate security groups per application layer

### High Availability
- ✅ Multi-AZ deployment (minimum 2 AZs)
- ✅ NAT Gateways in each AZ
- ✅ Load balancers across AZs
- ✅ RDS Multi-AZ for production

### Security
- ✅ Private subnets for applications (no direct internet)
- ✅ Database subnets isolated (no route to internet)
- ✅ NACLs as first line of defense
- ✅ Security Groups with least privilege
- ✅ VPC Endpoints for AWS service access

### Scalability
- ✅ /16 CIDR blocks allow for growth
- ✅ Transit Gateway supports 5,000+ attachments
- ✅ Modular design for easy expansion
- ✅ Reserved IP space for future accounts

### Cost Optimization
- ✅ VPC Endpoints reduce NAT Gateway costs
- ✅ Transit Gateway eliminates VPC peering mesh
- ✅ Single NAT Gateway per AZ (balance cost/HA)
- ✅ Flow Logs to S3 for cost-effective storage
