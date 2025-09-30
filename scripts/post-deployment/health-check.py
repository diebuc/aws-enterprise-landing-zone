#!/usr/bin/env python3
"""
AWS Landing Zone Health Check Script

Performs comprehensive health checks across the AWS Landing Zone deployment:
- Security services status (GuardDuty, Security Hub, Config)
- Compliance posture
- Network connectivity
- Cost and budget status
- Backup validation

Usage:
    python health-check.py --profile landing-zone
    python health-check.py --profile landing-zone --detailed
    python health-check.py --output json
"""

import boto3
import json
import sys
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Any
from dataclasses import dataclass, asdict

@dataclass
class HealthCheckResult:
    """Result of a health check"""
    service: str
    status: str  # 'PASS', 'WARN', 'FAIL'
    message: str
    details: Dict[str, Any] = None

class LandingZoneHealthCheck:
    """Comprehensive health checks for AWS Landing Zone"""
    
    def __init__(self, profile: str = None, region: str = 'us-east-1'):
        session = boto3.Session(profile_name=profile, region_name=region)
        self.organizations = session.client('organizations')
        self.guardduty = session.client('guardduty')
        self.securityhub = session.client('securityhub')
        self.config = session.client('config')
        self.cloudtrail = session.client('cloudtrail')
        self.ec2 = session.client('ec2')
        self.ce = session.client('ce')
        self.budgets = session.client('budgets')
        self.backup = session.client('backup')
        
        self.results: List[HealthCheckResult] = []
        
    def run_all_checks(self) -> List[HealthCheckResult]:
        """Run all health checks"""
        print("🏥 Running AWS Landing Zone Health Checks...\n")
        
        self.check_organizations()
        self.check_guardduty()
        self.check_security_hub()
        self.check_config()
        self.check_cloudtrail()
        self.check_transit_gateway()
        self.check_vpc_endpoints()
        self.check_costs()
        self.check_backups()
        
        return self.results
    
    def check_organizations(self):
        """Check AWS Organizations status"""
        try:
            org = self.organizations.describe_organization()
            
            # Check if all features enabled
            if org['Organization']['FeatureSet'] == 'ALL':
                self.results.append(HealthCheckResult(
                    service='AWS Organizations',
                    status='PASS',
                    message='All features enabled',
                    details={'org_id': org['Organization']['Id']}
                ))
            else:
                self.results.append(HealthCheckResult(
                    service='AWS Organizations',
                    status='WARN',
                    message='Consolidated billing only - should enable all features',
                    details={'feature_set': org['Organization']['FeatureSet']}
                ))
                
            # Check enabled policy types
            policy_types = org['Organization'].get('AvailablePolicyTypes', [])
            enabled_types = [pt['Type'] for pt in policy_types if pt.get('Status') == 'ENABLED']
            
            if 'SERVICE_CONTROL_POLICY' in enabled_types:
                self.results.append(HealthCheckResult(
                    service='Service Control Policies',
                    status='PASS',
                    message='SCPs enabled',
                    details={'enabled_types': enabled_types}
                ))
            else:
                self.results.append(HealthCheckResult(
                    service='Service Control Policies',
                    status='FAIL',
                    message='SCPs not enabled - critical security control missing'
                ))
                
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='AWS Organizations',
                status='FAIL',
                message=f'Error checking Organizations: {str(e)}'
            ))
    
    def check_guardduty(self):
        """Check GuardDuty status"""
        try:
            detectors = self.guardduty.list_detectors()
            
            if not detectors.get('DetectorIds'):
                self.results.append(HealthCheckResult(
                    service='GuardDuty',
                    status='FAIL',
                    message='GuardDuty not enabled'
                ))
                return
            
            detector_id = detectors['DetectorIds'][0]
            detector = self.guardduty.get_detector(DetectorId=detector_id)
            
            if detector['Status'] == 'ENABLED':
                # Check for HIGH/CRITICAL findings
                findings = self.guardduty.list_findings(
                    DetectorId=detector_id,
                    FindingCriteria={
                        'Criterion': {
                            'severity': {
                                'Gte': 7  # HIGH and CRITICAL (7-10)
                            },
                            'updatedAt': {
                                'Gte': int((datetime.now() - timedelta(days=7)).timestamp() * 1000)
                            }
                        }
                    }
                )
                
                finding_count = len(findings.get('FindingIds', []))
                
                if finding_count == 0:
                    self.results.append(HealthCheckResult(
                        service='GuardDuty',
                        status='PASS',
                        message='Enabled with no HIGH/CRITICAL findings in last 7 days',
                        details={'detector_id': detector_id}
                    ))
                else:
                    self.results.append(HealthCheckResult(
                        service='GuardDuty',
                        status='WARN',
                        message=f'{finding_count} HIGH/CRITICAL findings in last 7 days',
                        details={'finding_count': finding_count}
                    ))
            else:
                self.results.append(HealthCheckResult(
                    service='GuardDuty',
                    status='FAIL',
                    message=f'GuardDuty status: {detector["Status"]}'
                ))
                
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='GuardDuty',
                status='FAIL',
                message=f'Error checking GuardDuty: {str(e)}'
            ))
    
    def check_security_hub(self):
        """Check Security Hub status and compliance score"""
        try:
            hub = self.securityhub.describe_hub()
            
            if hub:
                # Get compliance score
                findings = self.securityhub.get_findings(
                    Filters={
                        'ComplianceStatus': [
                            {'Value': 'FAILED', 'Comparison': 'EQUALS'}
                        ],
                        'RecordState': [
                            {'Value': 'ACTIVE', 'Comparison': 'EQUALS'}
                        ]
                    },
                    MaxResults=100
                )
                
                failed_count = len(findings.get('Findings', []))
                
                if failed_count == 0:
                    self.results.append(HealthCheckResult(
                        service='Security Hub',
                        status='PASS',
                        message='Enabled with no failed compliance checks',
                        details={'hub_arn': hub['HubArn']}
                    ))
                elif failed_count < 10:
                    self.results.append(HealthCheckResult(
                        service='Security Hub',
                        status='WARN',
                        message=f'{failed_count} failed compliance checks',
                        details={'failed_count': failed_count}
                    ))
                else:
                    self.results.append(HealthCheckResult(
                        service='Security Hub',
                        status='FAIL',
                        message=f'{failed_count} failed compliance checks - exceeds threshold',
                        details={'failed_count': failed_count}
                    ))
                    
        except self.securityhub.exceptions.ResourceNotFoundException:
            self.results.append(HealthCheckResult(
                service='Security Hub',
                status='FAIL',
                message='Security Hub not enabled'
            ))
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='Security Hub',
                status='FAIL',
                message=f'Error checking Security Hub: {str(e)}'
            ))
    
    def check_config(self):
        """Check AWS Config status and compliance"""
        try:
            recorders = self.config.describe_configuration_recorders()
            
            if not recorders.get('ConfigurationRecorders'):
                self.results.append(HealthCheckResult(
                    service='AWS Config',
                    status='FAIL',
                    message='Config not enabled'
                ))
                return
            
            # Check recorder status
            recorder_status = self.config.describe_configuration_recorder_status()
            
            if recorder_status['ConfigurationRecordersStatus']:
                status = recorder_status['ConfigurationRecordersStatus'][0]
                
                if status['recording']:
                    # Check compliance
                    compliance = self.config.describe_compliance_by_config_rule()
                    
                    non_compliant = sum(
                        1 for rule in compliance.get('ComplianceByConfigRules', [])
                        if rule.get('Compliance', {}).get('ComplianceType') == 'NON_COMPLIANT'
                    )
                    
                    total_rules = len(compliance.get('ComplianceByConfigRules', []))
                    compliance_rate = ((total_rules - non_compliant) / total_rules * 100) if total_rules > 0 else 0
                    
                    if compliance_rate >= 95:
                        self.results.append(HealthCheckResult(
                            service='AWS Config',
                            status='PASS',
                            message=f'Recording enabled, {compliance_rate:.1f}% compliant',
                            details={
                                'total_rules': total_rules,
                                'non_compliant': non_compliant
                            }
                        ))
                    elif compliance_rate >= 90:
                        self.results.append(HealthCheckResult(
                            service='AWS Config',
                            status='WARN',
                            message=f'Recording enabled, {compliance_rate:.1f}% compliant (target: 95%)',
                            details={
                                'total_rules': total_rules,
                                'non_compliant': non_compliant
                            }
                        ))
                    else:
                        self.results.append(HealthCheckResult(
                            service='AWS Config',
                            status='FAIL',
                            message=f'Low compliance: {compliance_rate:.1f}%',
                            details={
                                'total_rules': total_rules,
                                'non_compliant': non_compliant
                            }
                        ))
                else:
                    self.results.append(HealthCheckResult(
                        service='AWS Config',
                        status='FAIL',
                        message='Config recorder not recording'
                    ))
                    
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='AWS Config',
                status='FAIL',
                message=f'Error checking Config: {str(e)}'
            ))
    
    def check_cloudtrail(self):
        """Check CloudTrail status"""
        try:
            trails = self.cloudtrail.describe_trails()
            
            if not trails.get('trailList'):
                self.results.append(HealthCheckResult(
                    service='CloudTrail',
                    status='FAIL',
                    message='No CloudTrail trails found'
                ))
                return
            
            # Check for organization trail
            org_trails = [t for t in trails['trailList'] if t.get('IsOrganizationTrail')]
            
            if org_trails:
                trail = org_trails[0]
                status = self.cloudtrail.get_trail_status(Name=trail['TrailARN'])
                
                if status['IsLogging']:
                    self.results.append(HealthCheckResult(
                        service='CloudTrail',
                        status='PASS',
                        message='Organization trail logging enabled',
                        details={'trail_arn': trail['TrailARN']}
                    ))
                else:
                    self.results.append(HealthCheckResult(
                        service='CloudTrail',
                        status='FAIL',
                        message='Organization trail exists but not logging'
                    ))
            else:
                self.results.append(HealthCheckResult(
                    service='CloudTrail',
                    status='WARN',
                    message='No organization trail found - using account trails'
                ))
                
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='CloudTrail',
                status='FAIL',
                message=f'Error checking CloudTrail: {str(e)}'
            ))
    
    def check_transit_gateway(self):
        """Check Transit Gateway status"""
        try:
            tgws = self.ec2.describe_transit_gateways()
            
            if not tgws.get('TransitGateways'):
                self.results.append(HealthCheckResult(
                    service='Transit Gateway',
                    status='WARN',
                    message='No Transit Gateway found (may be intentional)'
                ))
                return
            
            tgw = tgws['TransitGateways'][0]
            
            if tgw['State'] == 'available':
                # Check attachments
                attachments = self.ec2.describe_transit_gateway_attachments(
                    Filters=[
                        {'Name': 'transit-gateway-id', 'Values': [tgw['TransitGatewayId']]}
                    ]
                )
                
                attachment_count = len(attachments.get('TransitGatewayAttachments', []))
                
                self.results.append(HealthCheckResult(
                    service='Transit Gateway',
                    status='PASS',
                    message=f'Available with {attachment_count} attachments',
                    details={
                        'tgw_id': tgw['TransitGatewayId'],
                        'attachments': attachment_count
                    }
                ))
            else:
                self.results.append(HealthCheckResult(
                    service='Transit Gateway',
                    status='FAIL',
                    message=f'Transit Gateway state: {tgw["State"]}'
                ))
                
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='Transit Gateway',
                status='FAIL',
                message=f'Error checking Transit Gateway: {str(e)}'
            ))
    
    def check_vpc_endpoints(self):
        """Check VPC endpoints for cost optimization"""
        try:
            endpoints = self.ec2.describe_vpc_endpoints()
            
            endpoint_count = len(endpoints.get('VpcEndpoints', []))
            
            # Check for S3 gateway endpoint (free)
            s3_endpoints = [
                ep for ep in endpoints.get('VpcEndpoints', [])
                if 's3' in ep['ServiceName'] and ep['VpcEndpointType'] == 'Gateway'
            ]
            
            if s3_endpoints:
                self.results.append(HealthCheckResult(
                    service='VPC Endpoints',
                    status='PASS',
                    message=f'{endpoint_count} endpoints, including S3 gateway (cost optimized)',
                    details={'endpoint_count': endpoint_count}
                ))
            elif endpoint_count > 0:
                self.results.append(HealthCheckResult(
                    service='VPC Endpoints',
                    status='WARN',
                    message=f'{endpoint_count} endpoints, consider S3 gateway endpoint for cost savings'
                ))
            else:
                self.results.append(HealthCheckResult(
                    service='VPC Endpoints',
                    status='WARN',
                    message='No VPC endpoints - consider for AWS service access and cost optimization'
                ))
                
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='VPC Endpoints',
                status='FAIL',
                message=f'Error checking VPC endpoints: {str(e)}'
            ))
    
    def check_costs(self):
        """Check cost and budget status"""
        try:
            # Get yesterday's cost
            yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
            today = datetime.now().strftime('%Y-%m-%d')
            
            cost_response = self.ce.get_cost_and_usage(
                TimePeriod={'Start': yesterday, 'End': today},
                Granularity='DAILY',
                Metrics=['BlendedCost']
            )
            
            if cost_response['ResultsByTime']:
                daily_cost = float(cost_response['ResultsByTime'][0]['Total']['BlendedCost']['Amount'])
                estimated_monthly = daily_cost * 30
                
                # Check if within expected range (adjust based on your baseline)
                if estimated_monthly < 5000:  # Example threshold
                    self.results.append(HealthCheckResult(
                        service='Cost Management',
                        status='PASS',
                        message=f'Yesterday: ${daily_cost:.2f}, Est. monthly: ${estimated_monthly:.2f}',
                        details={
                            'daily_cost': daily_cost,
                            'estimated_monthly': estimated_monthly
                        }
                    ))
                else:
                    self.results.append(HealthCheckResult(
                        service='Cost Management',
                        status='WARN',
                        message=f'High costs detected - Est. monthly: ${estimated_monthly:.2f}',
                        details={
                            'daily_cost': daily_cost,
                            'estimated_monthly': estimated_monthly
                        }
                    ))
            
            # Check cost anomalies
            try:
                anomalies = self.ce.get_anomalies(
                    DateInterval={
                        'StartDate': (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
                    },
                    MaxResults=10
                )
                
                if anomalies.get('Anomalies'):
                    self.results.append(HealthCheckResult(
                        service='Cost Anomalies',
                        status='WARN',
                        message=f'{len(anomalies["Anomalies"])} cost anomalies detected in last 7 days'
                    ))
                else:
                    self.results.append(HealthCheckResult(
                        service='Cost Anomalies',
                        status='PASS',
                        message='No cost anomalies detected'
                    ))
            except:
                pass  # Cost anomaly detection may not be enabled
                
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='Cost Management',
                status='FAIL',
                message=f'Error checking costs: {str(e)}'
            ))
    
    def check_backups(self):
        """Check backup jobs status"""
        try:
            # Check recent backup jobs
            jobs = self.backup.list_backup_jobs(
                ByCreatedAfter=datetime.now() - timedelta(days=7)
            )
            
            if not jobs.get('BackupJobs'):
                self.results.append(HealthCheckResult(
                    service='AWS Backup',
                    status='WARN',
                    message='No backup jobs in last 7 days'
                ))
                return
            
            # Count job statuses
            completed = sum(1 for job in jobs['BackupJobs'] if job['State'] == 'COMPLETED')
            failed = sum(1 for job in jobs['BackupJobs'] if job['State'] == 'FAILED')
            total = len(jobs['BackupJobs'])
            
            success_rate = (completed / total * 100) if total > 0 else 0
            
            if success_rate >= 95:
                self.results.append(HealthCheckResult(
                    service='AWS Backup',
                    status='PASS',
                    message=f'{completed}/{total} backup jobs successful (last 7 days)',
                    details={
                        'completed': completed,
                        'failed': failed,
                        'total': total
                    }
                ))
            elif success_rate >= 90:
                self.results.append(HealthCheckResult(
                    service='AWS Backup',
                    status='WARN',
                    message=f'Backup success rate: {success_rate:.1f}% ({failed} failures)',
                    details={
                        'completed': completed,
                        'failed': failed,
                        'total': total
                    }
                ))
            else:
                self.results.append(HealthCheckResult(
                    service='AWS Backup',
                    status='FAIL',
                    message=f'Low backup success rate: {success_rate:.1f}%',
                    details={
                        'completed': completed,
                        'failed': failed,
                        'total': total
                    }
                ))
                
        except Exception as e:
            self.results.append(HealthCheckResult(
                service='AWS Backup',
                status='FAIL',
                message=f'Error checking backups: {str(e)}'
            ))
    
    def print_results(self):
        """Print results in human-readable format"""
        print("\n" + "="*80)
        print("AWS LANDING ZONE HEALTH CHECK RESULTS")
        print("="*80)
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")
        print()
        
        # Count by status
        passed = sum(1 for r in self.results if r.status == 'PASS')
        warnings = sum(1 for r in self.results if r.status == 'WARN')
        failed = sum(1 for r in self.results if r.status == 'FAIL')
        
        print(f"Overall Status: {passed} PASS | {warnings} WARN | {failed} FAIL")
        print()
        
        # Print by category
        for result in self.results:
            icon = {
                'PASS': '✅',
                'WARN': '⚠️',
                'FAIL': '❌'
            }.get(result.status, '❓')
            
            print(f"{icon} [{result.status:^4}] {result.service:<25} {result.message}")
            
            if result.details:
                for key, value in result.details.items():
                    print(f"        {key}: {value}")
        
        print("\n" + "="*80)
        
        # Overall health
        if failed > 0:
            print("🔴 HEALTH STATUS: CRITICAL - Immediate action required")
            return 2
        elif warnings > 0:
            print("🟡 HEALTH STATUS: WARNING - Review recommended")
            return 1
        else:
            print("🟢 HEALTH STATUS: HEALTHY - All checks passed")
            return 0
    
    def export_json(self, filename: str = None):
        """Export results as JSON"""
        output = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'passed': sum(1 for r in self.results if r.status == 'PASS'),
                'warnings': sum(1 for r in self.results if r.status == 'WARN'),
                'failed': sum(1 for r in self.results if r.status == 'FAIL')
            },
            'checks': [asdict(r) for r in self.results]
        }
        
        if filename:
            with open(filename, 'w') as f:
                json.dump(output, f, indent=2)
            print(f"\n📄 Results exported to: {filename}")
        else:
            print(json.dumps(output, indent=2))

def main():
    parser = argparse.ArgumentParser(description='AWS Landing Zone Health Check')
    parser.add_argument('--profile', help='AWS CLI profile name')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--output', choices=['text', 'json'], default='text', help='Output format')
    parser.add_argument('--export', help='Export JSON to file')
    parser.add_argument('--detailed', action='store_true', help='Show detailed information')
    
    args = parser.parse_args()
    
    try:
        checker = LandingZoneHealthCheck(profile=args.profile, region=args.region)
        checker.run_all_checks()
        
        if args.output == 'json':
            checker.export_json(args.export)
        else:
            exit_code = checker.print_results()
            
            if args.export:
                checker.export_json(args.export)
            
            sys.exit(exit_code)
            
    except Exception as e:
        print(f"❌ Error running health checks: {str(e)}", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()
