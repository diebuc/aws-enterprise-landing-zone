#!/usr/bin/env python3
"""
AWS Enterprise Landing Zone Cost Calculator

Estimates monthly and annual costs for enterprise landing zone deployment
based on organization size, data volumes, and service utilization patterns.

Usage:
    python cost-calculator.py --accounts 10 --employees 500 --data-gb 1000
    python cost-calculator.py --config-file org-config.json --output json
"""

import json
import argparse
import sys
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional
from pathlib import Path

@dataclass
class OrganizationProfile:
    """Organization profile for cost calculation"""
    name: str
    accounts_count: int
    employees: int
    regions: List[str]
    compliance_requirements: List[str]
    expected_data_gb_monthly: int
    business_hours_only: bool = False
    development_accounts_ratio: float = 0.3

@dataclass
class ServiceCost:
    """Individual AWS service cost breakdown"""
    service_name: str
    monthly_cost: float
    annual_cost: float
    cost_drivers: List[str]
    optimization_potential: float
    cost_tier: str = "standard"  # standard, enterprise, premium

class AWSPricing:
    """AWS service pricing constants (US-East-1, September 2024)"""
    
    # Control Tower
    CONTROL_TOWER_BASE = 89.10
    
    # GuardDuty (per account per month)
    GUARDDUTY_BASE_PER_ACCOUNT = 15.60
    GUARDDUTY_CLOUDTRAIL_PER_100K_EVENTS = 0.10
    GUARDDUTY_DNS_PER_GB = 0.50
    
    # Config
    CONFIG_ITEM_PRICE = 0.003
    CONFIG_RULE_EVALUATION_PRICE = 0.001
    CONFIG_TYPICAL_PER_ACCOUNT = 23.40
    
    # Transit Gateway
    TGW_ATTACHMENT_HOURLY = 0.05
    TGW_DATA_PROCESSING_PER_GB = 0.02
    
    # CloudTrail
    CLOUDTRAIL_DATA_EVENTS_PER_100K = 0.10
    CLOUDTRAIL_INSIGHTS_PER_100K = 0.35
    CLOUDTRAIL_TYPICAL_MONTHLY = 67.50
    
    # CloudWatch
    CLOUDWATCH_LOG_INGESTION_PER_GB = 0.50
    CLOUDWATCH_LOG_STORAGE_PER_GB_MONTH = 0.03
    CLOUDWATCH_TYPICAL_PER_ACCOUNT = 7.89
    
    # Security Hub
    SECURITY_HUB_FINDING_INGESTION_PER_100K = 0.30
    SECURITY_HUB_COMPLIANCE_CHECKS_PER_100K = 0.10
    
    # Systems Manager
    SYSTEMS_MANAGER_PARAMETER_STORE_STANDARD = 0.05
    SYSTEMS_MANAGER_AUTOMATION_PER_STEP = 0.002
    
    # Backup
    AWS_BACKUP_STORAGE_PER_GB_MONTH = 0.05
    AWS_BACKUP_CROSS_REGION_COPY_PER_GB = 0.02

class LandingZoneCostCalculator:
    """Calculate costs for AWS Enterprise Landing Zone"""
    
    def __init__(self, org_profile: OrganizationProfile):
        self.org_profile = org_profile
        self.pricing = AWSPricing()
        
    def calculate_control_tower_costs(self) -> ServiceCost:
        """Calculate AWS Control Tower costs"""
        monthly_cost = self.pricing.CONTROL_TOWER_BASE
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            f"Base Control Tower service for {self.org_profile.accounts_count} accounts",
            "Automated guardrails and compliance monitoring",
            "Account Factory for automated provisioning",
            "Service Catalog integration"
        ]
        
        # Control Tower has fixed pricing
        optimization_potential = 0.0
        
        return ServiceCost(
            service_name="AWS Control Tower",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="enterprise"
        )
    
    def calculate_guardduty_costs(self) -> ServiceCost:
        """Calculate GuardDuty costs across all accounts"""
        base_monthly = self.pricing.GUARDDUTY_BASE_PER_ACCOUNT * self.org_profile.accounts_count
        
        # Additional costs based on data volume
        events_per_month = self.org_profile.expected_data_gb_monthly * 100  # Estimate events from data
        cloudtrail_events_cost = (events_per_month / 100000) * self.pricing.GUARDDUTY_CLOUDTRAIL_PER_100K_EVENTS
        dns_logs_cost = self.org_profile.expected_data_gb_monthly * self.pricing.GUARDDUTY_DNS_PER_GB
        
        monthly_cost = base_monthly + cloudtrail_events_cost + dns_logs_cost
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            f"Base GuardDuty for {self.org_profile.accounts_count} accounts",
            f"CloudTrail event analysis: ~{events_per_month:,.0f} events/month",
            f"DNS log analysis: {self.org_profile.expected_data_gb_monthly} GB/month",
            "Threat intelligence feeds and ML model inference"
        ]
        
        # Intelligent tiering can reduce costs by 20%
        optimization_potential = 0.20
        
        return ServiceCost(
            service_name="Amazon GuardDuty",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="premium"
        )
    
    def calculate_config_costs(self) -> ServiceCost:
        """Calculate AWS Config costs"""
        # Estimate configuration items per account (EC2, VPC, Security Groups, etc.)
        config_items_per_account = 500  # Conservative estimate
        total_config_items = config_items_per_account * self.org_profile.accounts_count
        
        # Rule evaluations (assume 50 rules per account, evaluated 4 times per day)
        rule_evaluations_per_month = self.org_profile.accounts_count * 50 * 4 * 30
        
        monthly_cost = (
            (total_config_items * self.pricing.CONFIG_ITEM_PRICE) +
            (rule_evaluations_per_month * self.pricing.CONFIG_RULE_EVALUATION_PRICE)
        )
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            f"Configuration items: ~{total_config_items:,} items/month",
            f"Rule evaluations: ~{rule_evaluations_per_month:,} evaluations/month",
            f"Compliance monitoring across {len(self.org_profile.compliance_requirements)} frameworks",
            "Configuration history and snapshots"
        ]
        
        # Rule consolidation and retention optimization
        optimization_potential = 0.25
        
        return ServiceCost(
            service_name="AWS Config",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="standard"
        )
    
    def calculate_transit_gateway_costs(self) -> ServiceCost:
        """Calculate Transit Gateway costs"""
        # Estimate 2 attachments per account (workload + shared services)
        attachments_per_account = 2
        total_attachments = self.org_profile.accounts_count * attachments_per_account
        
        # Account for multiple regions
        region_multiplier = len(self.org_profile.regions)
        total_attachments *= region_multiplier
        
        # Attachment costs (hourly)
        hours_per_month = 24 * 30
        attachment_cost = total_attachments * self.pricing.TGW_ATTACHMENT_HOURLY * hours_per_month
        
        # Data processing costs
        # Assume 70% of data traverses TGW
        tgw_data_gb = self.org_profile.expected_data_gb_monthly * 0.7
        data_processing_cost = tgw_data_gb * self.pricing.TGW_DATA_PROCESSING_PER_GB
        
        monthly_cost = attachment_cost + data_processing_cost
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            f"VPC attachments: {total_attachments} attachments across {region_multiplier} regions",
            f"Data processing: ~{tgw_data_gb:.0f} GB/month @ $0.02/GB",
            f"Cross-AZ data transfer costs",
            "Route table associations and propagations"
        ]
        
        # Reserved instances and traffic optimization
        optimization_potential = 0.30
        
        return ServiceCost(
            service_name="AWS Transit Gateway",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="standard"
        )
    
    def calculate_cloudtrail_costs(self) -> ServiceCost:
        """Calculate CloudTrail costs"""
        base_cost = self.pricing.CLOUDTRAIL_TYPICAL_MONTHLY
        
        # Data events cost (S3, Lambda)
        data_events_per_month = self.org_profile.expected_data_gb_monthly * 50  # Estimate
        data_events_cost = (data_events_per_month / 100000) * self.pricing.CLOUDTRAIL_DATA_EVENTS_PER_100K
        
        # Insights cost
        insights_cost = (data_events_per_month / 100000) * self.pricing.CLOUDTRAIL_INSIGHTS_PER_100K * 0.1  # 10% insights
        
        monthly_cost = base_cost + data_events_cost + insights_cost
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            "Organization-wide CloudTrail with management events",
            f"Data events: ~{data_events_per_month:,.0f} events/month",
            "CloudTrail Insights for anomaly detection (10% of events)",
            "Cross-region log replication for DR"
        ]
        
        # Event filtering and selective data events
        optimization_potential = 0.15
        
        return ServiceCost(
            service_name="AWS CloudTrail",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="standard"
        )
    
    def calculate_cloudwatch_costs(self) -> ServiceCost:
        """Calculate CloudWatch Logs and monitoring costs"""
        base_cost = self.pricing.CLOUDWATCH_TYPICAL_PER_ACCOUNT * self.org_profile.accounts_count
        
        # Log ingestion (VPC Flow Logs, Application Logs, etc.)
        log_ingestion_gb = self.org_profile.expected_data_gb_monthly * 0.3  # 30% becomes logs
        ingestion_cost = log_ingestion_gb * self.pricing.CLOUDWATCH_LOG_INGESTION_PER_GB
        
        # Log storage (with retention)
        avg_retention_months = 6  # Average across different log types
        storage_cost = log_ingestion_gb * avg_retention_months * self.pricing.CLOUDWATCH_LOG_STORAGE_PER_GB_MONTH
        
        monthly_cost = base_cost + ingestion_cost + storage_cost
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            f"Log ingestion: ~{log_ingestion_gb:.0f} GB/month across {self.org_profile.accounts_count} accounts",
            f"Log storage: ~{log_ingestion_gb * avg_retention_months:.0f} GB with average {avg_retention_months} month retention",
            "Custom metrics and dashboards",
            "Cross-account metric sharing"
        ]
        
        # Log retention optimization and filtering
        optimization_potential = 0.40
        
        return ServiceCost(
            service_name="Amazon CloudWatch",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="standard"
        )
    
    def calculate_security_hub_costs(self) -> ServiceCost:
        """Calculate Security Hub costs"""
        # Findings ingestion from multiple sources
        findings_per_month = self.org_profile.accounts_count * 10000  # Conservative estimate
        ingestion_cost = (findings_per_month / 100000) * self.pricing.SECURITY_HUB_FINDING_INGESTION_PER_100K
        
        # Compliance checks
        compliance_checks_per_month = self.org_profile.accounts_count * len(self.org_profile.compliance_requirements) * 1000
        compliance_cost = (compliance_checks_per_month / 100000) * self.pricing.SECURITY_HUB_COMPLIANCE_CHECKS_PER_100K
        
        monthly_cost = ingestion_cost + compliance_cost
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            f"Security findings ingestion: ~{findings_per_month:,} findings/month",
            f"Compliance checks: ~{compliance_checks_per_month:,} checks/month",
            f"Standards: {', '.join(self.org_profile.compliance_requirements)}",
            "Cross-account security posture aggregation"
        ]
        
        optimization_potential = 0.10  # Limited optimization potential
        
        return ServiceCost(
            service_name="AWS Security Hub",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="premium"
        )
    
    def calculate_backup_costs(self) -> ServiceCost:
        """Calculate AWS Backup costs"""
        # Estimate backup storage needs
        # Assume 100GB per production account, 30GB per dev account
        prod_accounts = int(self.org_profile.accounts_count * (1 - self.org_profile.development_accounts_ratio))
        dev_accounts = self.org_profile.accounts_count - prod_accounts
        
        backup_storage_gb = (prod_accounts * 100) + (dev_accounts * 30)
        storage_cost = backup_storage_gb * self.pricing.AWS_BACKUP_STORAGE_PER_GB_MONTH
        
        # Cross-region copy for DR (50% of backups)
        cross_region_gb = backup_storage_gb * 0.5
        cross_region_cost = cross_region_gb * self.pricing.AWS_BACKUP_CROSS_REGION_COPY_PER_GB
        
        monthly_cost = storage_cost + cross_region_cost
        annual_cost = monthly_cost * 12
        
        cost_drivers = [
            f"Backup storage: ~{backup_storage_gb:.0f} GB across {self.org_profile.accounts_count} accounts",
            f"Cross-region replication: ~{cross_region_gb:.0f} GB for DR",
            "EBS snapshots, RDS backups, EFS backups",
            "Automated backup lifecycle management"
        ]
        
        optimization_potential = 0.25  # Lifecycle policies and deduplication
        
        return ServiceCost(
            service_name="AWS Backup",
            monthly_cost=monthly_cost,
            annual_cost=annual_cost,
            cost_drivers=cost_drivers,
            optimization_potential=optimization_potential,
            cost_tier="standard"
        )
    
    def generate_cost_report(self) -> Dict:
        """Generate comprehensive cost report"""
        services = [
            self.calculate_control_tower_costs(),
            self.calculate_guardduty_costs(),
            self.calculate_config_costs(),
            self.calculate_transit_gateway_costs(),
            self.calculate_cloudtrail_costs(),
            self.calculate_cloudwatch_costs(),
            self.calculate_security_hub_costs(),
            self.calculate_backup_costs()
        ]
        
        # Calculate totals
        total_monthly = sum(service.monthly_cost for service in services)
        total_annual = sum(service.annual_cost for service in services)
        
        # Calculate optimized costs
        optimized_monthly = sum(
            service.monthly_cost * (1 - service.optimization_potential) 
            for service in services
        )
        optimized_annual = optimized_monthly * 12
        
        # Potential savings
        potential_savings_monthly = total_monthly - optimized_monthly
        potential_savings_annual = total_annual - optimized_annual
        
        # Cost per employee analysis
        cost_per_employee_monthly = total_monthly / self.org_profile.employees
        cost_per_employee_annual = total_annual / self.org_profile.employees
        
        return {
            "organization_profile": asdict(self.org_profile),
            "cost_analysis": {
                "timestamp": "2024-09-25T00:00:00Z",
                "currency": "USD",
                "region_basis": "us-east-1"
            },
            "cost_breakdown": {
                "services": [
                    {
                        "name": service.service_name,
                        "monthly_cost": round(service.monthly_cost, 2),
                        "annual_cost": round(service.annual_cost, 2),
                        "cost_drivers": service.cost_drivers,
                        "optimization_potential_pct": round(service.optimization_potential * 100, 1),
                        "cost_tier": service.cost_tier,
                        "percentage_of_total": round((service.monthly_cost / total_monthly) * 100, 1)
                    }
                    for service in services
                ],
                "totals": {
                    "monthly_cost": round(total_monthly, 2),
                    "annual_cost": round(total_annual, 2),
                    "optimized_monthly": round(optimized_monthly, 2),
                    "optimized_annual": round(optimized_annual, 2),
                    "potential_savings": {
                        "monthly": round(potential_savings_monthly, 2),
                        "annual": round(potential_savings_annual, 2),
                        "percentage": round((potential_savings_annual / total_annual) * 100, 1)
                    }
                }
            },
            "business_metrics": {
                "cost_per_employee": {
                    "monthly": round(cost_per_employee_monthly, 2),
                    "annual": round(cost_per_employee_annual, 2)
                },
                "cost_per_account": {
                    "monthly": round(total_monthly / self.org_profile.accounts_count, 2),
                    "annual": round(total_annual / self.org_profile.accounts_count, 2)
                }
            },
            "recommendations": self._generate_recommendations(services, total_annual),
            "risk_analysis": self._generate_risk_analysis(total_monthly)
        }
    
    def _generate_recommendations(self, services: List[ServiceCost], total_annual: float) -> List[Dict]:
        """Generate cost optimization recommendations"""
        recommendations = []
        
        # High-impact recommendations
        recommendations.extend([
            {
                "priority": "high",
                "category": "cost_optimization",
                "title": "Implement Transit Gateway Reserved Instances",
                "description": "Purchase 1-year reserved instances for Transit Gateway attachments",
                "estimated_savings_annual": total_annual * 0.15,
                "implementation_effort": "low"
            },
            {
                "priority": "high", 
                "category": "log_optimization",
                "title": "Configure CloudWatch Logs retention policies",
                "description": "Implement tiered retention: 30 days (debug), 90 days (info), 365 days (error)",
                "estimated_savings_annual": total_annual * 0.12,
                "implementation_effort": "medium"
            }
        ])
        
        # Medium-impact recommendations
        if self.org_profile.accounts_count > 20:
            recommendations.append({
                "priority": "medium",
                "category": "governance",
                "title": "Implement account-level budget controls",
                "description": "Set up automated budget alerts and spending limits per account",
                "estimated_savings_annual": total_annual * 0.08,
                "implementation_effort": "high"
            })
        
        # Compliance-specific recommendations
        if "pci-dss" in self.org_profile.compliance_requirements:
            recommendations.append({
                "priority": "medium",
                "category": "compliance",
                "title": "Optimize PCI DSS scope",
                "description": "Reduce PCI DSS scope by network segmentation and data flow optimization",
                "estimated_savings_annual": total_annual * 0.05,
                "implementation_effort": "high"
            })
        
        return recommendations
    
    def _generate_risk_analysis(self, monthly_cost: float) -> Dict:
        """Generate cost risk analysis"""
        risk_factors = []
        
        # High monthly cost risk
        if monthly_cost > 2000:
            risk_factors.append({
                "risk": "high_monthly_spend",
                "description": "Monthly spend exceeds $2,000 - implement strict monitoring",
                "mitigation": "Set up daily cost alerts and weekly reviews"
            })
        
        # Multi-region risk
        if len(self.org_profile.regions) > 2:
            risk_factors.append({
                "risk": "multi_region_complexity",
                "description": "Multi-region deployment increases data transfer costs",
                "mitigation": "Optimize cross-region traffic patterns and implement data locality"
            })
        
        # Account proliferation risk
        if self.org_profile.accounts_count > 50:
            risk_factors.append({
                "risk": "account_sprawl",
                "description": "Large number of accounts may lead to governance challenges",
                "mitigation": "Implement automated account lifecycle management"
            })
        
        return {
            "risk_level": "high" if len(risk_factors) >= 2 else "medium" if risk_factors else "low",
            "risk_factors": risk_factors
        }

def load_config_file(config_path: str) -> OrganizationProfile:
    """Load organization configuration from JSON file"""
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        return OrganizationProfile(
            name=config.get('name', 'Enterprise Organization'),
            accounts_count=config.get('accounts_count', 10),
            employees=config.get('employees', 500),
            regions=config.get('regions', ['us-east-1']),
            compliance_requirements=config.get('compliance_requirements', ['sox', 'pci-dss']),
            expected_data_gb_monthly=config.get('expected_data_gb_monthly', 1000),
            business_hours_only=config.get('business_hours_only', False),
            development_accounts_ratio=config.get('development_accounts_ratio', 0.3)
        )
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading config file: {e}")
        sys.exit(1)

def print_summary_report(report: Dict):
    """Print human-readable cost summary"""
    print("\n" + "="*80)
    print("AWS ENTERPRISE LANDING ZONE - COST ANALYSIS")
    print("="*80)
    
    org = report["organization_profile"]
    totals = report["cost_breakdown"]["totals"]
    business = report["business_metrics"]
    
    print(f"\n📊 ORGANIZATION PROFILE")
    print(f"Name: {org['name']}")
    print(f"Accounts: {org['accounts_count']} | Employees: {org['employees']} | Regions: {len(org['regions'])}")
    print(f"Compliance: {', '.join(org['compliance_requirements'])}")
    
    print(f"\n💰 COST SUMMARY")
    print(f"Monthly Cost: ${totals['monthly_cost']:,.2f}")
    print(f"Annual Cost:  ${totals['annual_cost']:,.2f}")
    print(f"Cost per Employee/Year: ${business['cost_per_employee']['annual']:,.2f}")
    print(f"Cost per Account/Month: ${business['cost_per_account']['monthly']:,.2f}")
    
    print(f"\n🎯 OPTIMIZATION POTENTIAL")
    print(f"Optimized Monthly: ${totals['optimized_monthly']:,.2f}")
    print(f"Optimized Annual:  ${totals['optimized_annual']:,.2f}")
    print(f"Potential Savings: ${totals['potential_savings']['annual']:,.2f} ({totals['potential_savings']['percentage']}%)")
    
    print(f"\n🔍 SERVICE BREAKDOWN")
    for service in report["cost_breakdown"]["services"]:
        print(f"  {service['name']:<25} ${service['monthly_cost']:>8.2f}/mo  ${service['annual_cost']:>10.2f}/yr  ({service['percentage_of_total']:>4.1f}%)")
    
    print(f"\n💡 TOP RECOMMENDATIONS")
    for i, rec in enumerate(report["recommendations"][:3], 1):
        savings = rec.get('estimated_savings_annual', 0)
        print(f"  {i}. {rec['title']}")
        print(f"     Potential savings: ${savings:,.0f}/year | Effort: {rec['implementation_effort']}")
    
    # Risk Analysis
    risk = report["risk_analysis"]
    risk_icon = "🔴" if risk['risk_level'] == 'high' else "🟡" if risk['risk_level'] == 'medium' else "🟢"
    print(f"\n{risk_icon} RISK ASSESSMENT: {risk['risk_level'].upper()}")
    
    if risk['risk_factors']:
        for factor in risk['risk_factors'][:2]:  # Show top 2 risks
            print(f"  • {factor['description']}")
    
    print("\n" + "="*80)

def main():
    """Main function for CLI usage"""
    parser = argparse.ArgumentParser(description="Calculate AWS Landing Zone costs")
    parser.add_argument("--accounts", type=int, default=10, help="Number of AWS accounts")
    parser.add_argument("--employees", type=int, default=500, help="Number of employees")
    parser.add_argument("--data-gb", type=int, default=1000, help="Expected monthly data volume in GB")
    parser.add_argument("--regions", nargs='+', default=['us-east-1'], help="AWS regions")
    parser.add_argument("--compliance", nargs='+', default=['sox', 'pci-dss'], help="Compliance frameworks")
    parser.add_argument("--config-file", type=str, help="Path to JSON configuration file")
    parser.add_argument("--output", choices=["json", "summary"], default="summary", help="Output format")
    parser.add_argument("--save-report", type=str, help="Save detailed report to file")
    
    args = parser.parse_args()
    
    # Create organization profile
    if args.config_file:
        org_profile = load_config_file(args.config_file)
    else:
        org_profile = OrganizationProfile(
            name="Enterprise Organization",
            accounts_count=args.accounts,
            employees=args.employees,
            regions=args.regions,
            compliance_requirements=args.compliance,
            expected_data_gb_monthly=args.data_gb
        )
    
    # Calculate costs
    calculator = LandingZoneCostCalculator(org_profile)
    report = calculator.generate_cost_report()
    
    # Output results
    if args.output == "json":
        print(json.dumps(report, indent=2))
    else:
        print_summary_report(report)
    
    # Save detailed report if requested
    if args.save_report:
        with open(args.save_report, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\n📄 Detailed report saved to: {args.save_report}")

if __name__ == "__main__":
    main()
