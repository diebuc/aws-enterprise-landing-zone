#!/usr/bin/env python3
"""
AWS Landing Zone Compliance Reporter
Generates compliance reports across all organization accounts
"""

import boto3
import json
from datetime import datetime
from collections import defaultdict
import sys

class ComplianceReporter:
    def __init__(self):
        self.org_client = boto3.client('organizations')
        self.config_client = boto3.client('config')
        self.securityhub_client = boto3.client('securityhub')
        self.guardduty_client = boto3.client('guardduty')
        
    def get_all_accounts(self):
        """Retrieve all AWS accounts in the organization"""
        try:
            response = self.org_client.list_accounts()
            return [acc for acc in response['Accounts'] if acc['Status'] == 'ACTIVE']
        except Exception as e:
            print(f"❌ Error fetching accounts: {e}")
            return []
    
    def check_config_compliance(self, account_id):
        """Check AWS Config compliance rules for an account"""
        try:
            response = self.config_client.describe_compliance_by_config_rule()
            compliant = 0
            non_compliant = 0
            
            for rule in response.get('ComplianceByConfigRules', []):
                compliance = rule['Compliance']['ComplianceType']
                if compliance == 'COMPLIANT':
                    compliant += 1
                elif compliance == 'NON_COMPLIANT':
                    non_compliant += 1
            
            return {
                'compliant': compliant,
                'non_compliant': non_compliant,
                'total': compliant + non_compliant,
                'score': (compliant / (compliant + non_compliant) * 100) if (compliant + non_compliant) > 0 else 0
            }
        except Exception as e:
            print(f"⚠️  Config check failed for {account_id}: {e}")
            return {'compliant': 0, 'non_compliant': 0, 'total': 0, 'score': 0}
    
    def check_security_hub_findings(self, account_id):
        """Check Security Hub findings severity distribution"""
        try:
            response = self.securityhub_client.get_findings(
                Filters={
                    'RecordState': [{'Value': 'ACTIVE', 'Comparison': 'EQUALS'}]
                },
                MaxResults=100
            )
            
            severity_counts = defaultdict(int)
            for finding in response.get('Findings', []):
                severity = finding.get('Severity', {}).get('Label', 'UNKNOWN')
                severity_counts[severity] += 1
            
            return dict(severity_counts)
        except Exception as e:
            print(f"⚠️  Security Hub check failed for {account_id}: {e}")
            return {}
    
    def check_guardduty_status(self, account_id):
        """Verify GuardDuty is enabled and get threat counts"""
        try:
            response = self.guardduty_client.list_detectors()
            if not response['DetectorIds']:
                return {'enabled': False, 'threats': 0}
            
            detector_id = response['DetectorIds'][0]
            findings = self.guardduty_client.list_findings(
                DetectorId=detector_id,
                FindingCriteria={
                    'Criterion': {
                        'service.archived': {'Eq': ['false']}
                    }
                }
            )
            
            return {
                'enabled': True,
                'threats': len(findings.get('FindingIds', []))
            }
        except Exception as e:
            print(f"⚠️  GuardDuty check failed for {account_id}: {e}")
            return {'enabled': False, 'threats': 0}
    
    def generate_report(self):
        """Generate comprehensive compliance report"""
        print("=" * 70)
        print("AWS LANDING ZONE COMPLIANCE REPORT".center(70))
        print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}".center(70))
        print("=" * 70)
        print()
        
        accounts = self.get_all_accounts()
        print(f"📊 Analyzing {len(accounts)} accounts in organization...\n")
        
        total_score = 0
        critical_issues = 0
        high_issues = 0
        
        for account in accounts:
            account_id = account['Id']
            account_name = account['Name']
            
            print(f"\n{'─' * 70}")
            print(f"🏢 Account: {account_name} ({account_id})")
            print(f"{'─' * 70}")
            
            # AWS Config Compliance
            config_results = self.check_config_compliance(account_id)
            print(f"\n  ✓ AWS Config Compliance:")
            print(f"    Compliant Rules: {config_results['compliant']}")
            print(f"    Non-Compliant Rules: {config_results['non_compliant']}")
            print(f"    Compliance Score: {config_results['score']:.1f}%")
            
            if config_results['score'] < 90:
                print(f"    ⚠️  WARNING: Compliance score below 90%")
            
            total_score += config_results['score']
            
            # Security Hub Findings
            sh_findings = self.check_security_hub_findings(account_id)
            if sh_findings:
                print(f"\n  🔍 Security Hub Findings:")
                for severity, count in sorted(sh_findings.items()):
                    icon = "🔴" if severity == "CRITICAL" else "🟠" if severity == "HIGH" else "🟡"
                    print(f"    {icon} {severity}: {count}")
                    
                    if severity == "CRITICAL":
                        critical_issues += count
                    elif severity == "HIGH":
                        high_issues += count
            
            # GuardDuty Status
            gd_status = self.check_guardduty_status(account_id)
            print(f"\n  🛡️  GuardDuty:")
            print(f"    Status: {'✅ Enabled' if gd_status['enabled'] else '❌ Disabled'}")
            print(f"    Active Threats: {gd_status['threats']}")
            
        # Summary
        print(f"\n\n{'═' * 70}")
        print("COMPLIANCE SUMMARY".center(70))
        print(f"{'═' * 70}")
        
        avg_score = total_score / len(accounts) if accounts else 0
        print(f"\n  Average Compliance Score: {avg_score:.1f}%")
        print(f"  Critical Security Issues: {critical_issues}")
        print(f"  High Security Issues: {high_issues}")
        
        if avg_score >= 95 and critical_issues == 0:
            print(f"\n  ✅ Status: EXCELLENT - Landing Zone meets enterprise standards")
        elif avg_score >= 90 and critical_issues == 0:
            print(f"\n  ✓ Status: GOOD - Minor improvements recommended")
        elif critical_issues > 0:
            print(f"\n  ⚠️  Status: ACTION REQUIRED - Critical issues detected")
        else:
            print(f"\n  ⚠️  Status: NEEDS IMPROVEMENT - Below compliance threshold")
        
        print(f"\n{'═' * 70}\n")
        
        return {
            'average_score': avg_score,
            'critical_issues': critical_issues,
            'high_issues': high_issues,
            'accounts_analyzed': len(accounts)
        }

def main():
    print("\n🔍 Starting AWS Landing Zone Compliance Audit...\n")
    
    try:
        reporter = ComplianceReporter()
        results = reporter.generate_report()
        
        # Exit with appropriate code
        if results['critical_issues'] > 0:
            sys.exit(1)
        elif results['average_score'] < 90:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        sys.exit(2)

if __name__ == "__main__":
    main()
