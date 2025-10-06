#!/usr/bin/env python3
"""
AWS Landing Zone Visual Report Generator
Creates HTML reports with charts and visualizations
"""

import boto3
import json
from datetime import datetime, timedelta
from collections import defaultdict
import sys

class ReportGenerator:
    def __init__(self):
        self.org_client = boto3.client('organizations')
        self.ce_client = boto3.client('ce')
        self.config_client = boto3.client('config')
        self.securityhub_client = boto3.client('securityhub')
        
    def get_cost_data(self, days=30):
        """Get cost and usage data for the last N days"""
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days)
        
        try:
            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date.strftime('%Y-%m-%d'),
                    'End': end_date.strftime('%Y-%m-%d')
                },
                Granularity='DAILY',
                Metrics=['UnblendedCost'],
                GroupBy=[
                    {'Type': 'DIMENSION', 'Key': 'SERVICE'}
                ]
            )
            
            return response['ResultsByTime']
        except Exception as e:
            print(f"⚠️  Could not fetch cost data: {e}")
            return []
    
    def get_security_metrics(self):
        """Get security findings summary"""
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
            print(f"⚠️  Could not fetch security metrics: {e}")
            return {}
    
    def get_compliance_summary(self):
        """Get AWS Config compliance summary"""
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
            
            total = compliant + non_compliant
            score = (compliant / total * 100) if total > 0 else 0
            
            return {
                'compliant': compliant,
                'non_compliant': non_compliant,
                'total': total,
                'score': score
            }
        except Exception as e:
            print(f"⚠️  Could not fetch compliance data: {e}")
            return {'compliant': 0, 'non_compliant': 0, 'total': 0, 'score': 0}
    
    def generate_html_report(self, output_file='landing-zone-report.html'):
        """Generate comprehensive HTML report"""
        print("🔍 Gathering data for report...")
        
        cost_data = self.get_cost_data(30)
        security_metrics = self.get_security_metrics()
        compliance_summary = self.get_compliance_summary()
        
        # Calculate total cost
        total_cost = 0
        cost_by_service = defaultdict(float)
        
        for day in cost_data:
            for group in day.get('Groups', []):
                service = group['Keys'][0]
                amount = float(group['Metrics']['UnblendedCost']['Amount'])
                cost_by_service[service] += amount
                total_cost += amount
        
        # Get top 5 services by cost
        top_services = sorted(cost_by_service.items(), key=lambda x: x[1], reverse=True)[:5]
        
        # Generate HTML
        html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Landing Zone Report - {datetime.now().strftime('%Y-%m-%d')}</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
        }}
        
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }}
        
        header {{
            background: linear-gradient(135deg, #232F3E 0%, #FF9900 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }}
        
        header h1 {{
            font-size: 2.5em;
            margin-bottom: 10px;
        }}
        
        header p {{
            font-size: 1.1em;
            opacity: 0.9;
        }}
        
        .metrics {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 40px;
        }}
        
        .metric-card {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 12px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }}
        
        .metric-card:hover {{
            transform: translateY(-5px);
        }}
        
        .metric-card.cost {{
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        }}
        
        .metric-card.security {{
            background: linear-gradient(135deg, #ee0979 0%, #ff6a00 100%);
        }}
        
        .metric-card.compliance {{
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        }}
        
        .metric-card h3 {{
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
            opacity: 0.9;
        }}
        
        .metric-value {{
            font-size: 3em;
            font-weight: bold;
            margin: 10px 0;
        }}
        
        .metric-label {{
            font-size: 0.9em;
            opacity: 0.8;
        }}
        
        .charts {{
            padding: 40px;
            background: #f8f9fa;
        }}
        
        .chart-container {{
            background: white;
            padding: 30px;
            border-radius: 12px;
            margin-bottom: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }}
        
        .chart-container h2 {{
            color: #232F3E;
            margin-bottom: 20px;
            font-size: 1.5em;
        }}
        
        canvas {{
            max-height: 400px;
        }}
        
        .status {{
            padding: 40px;
            text-align: center;
        }}
        
        .status-badge {{
            display: inline-block;
            padding: 15px 40px;
            border-radius: 50px;
            font-size: 1.2em;
            font-weight: bold;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}
        
        .status-excellent {{
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
            color: white;
        }}
        
        .status-good {{
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
        }}
        
        .status-warning {{
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
            color: #232F3E;
        }}
        
        footer {{
            background: #232F3E;
            color: white;
            text-align: center;
            padding: 20px;
            font-size: 0.9em;
        }}
        
        .table-container {{
            padding: 0 40px 40px 40px;
        }}
        
        table {{
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }}
        
        th {{
            background: #232F3E;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }}
        
        td {{
            padding: 15px;
            border-bottom: 1px solid #e9ecef;
        }}
        
        tr:hover {{
            background: #f8f9fa;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🏢 AWS Landing Zone Report</h1>
            <p>Generated on {datetime.now().strftime('%B %d, %Y at %H:%M:%S UTC')}</p>
        </header>
        
        <div class="metrics">
            <div class="metric-card cost">
                <h3>Total Cost (30 days)</h3>
                <div class="metric-value">${total_cost:.2f}</div>
                <div class="metric-label">Unblended Cost</div>
            </div>
            
            <div class="metric-card security">
                <h3>Active Security Findings</h3>
                <div class="metric-value">{sum(security_metrics.values())}</div>
                <div class="metric-label">Security Hub Alerts</div>
            </div>
            
            <div class="metric-card compliance">
                <h3>Compliance Score</h3>
                <div class="metric-value">{compliance_summary['score']:.1f}%</div>
                <div class="metric-label">AWS Config Rules</div>
            </div>
        </div>
        
        <div class="charts">
            <div class="chart-container">
                <h2>📊 Cost by Service (Top 5)</h2>
                <canvas id="costChart"></canvas>
            </div>
            
            <div class="chart-container">
                <h2>🔐 Security Findings by Severity</h2>
                <canvas id="securityChart"></canvas>
            </div>
            
            <div class="chart-container">
                <h2>✅ Compliance Status</h2>
                <canvas id="complianceChart"></canvas>
            </div>
        </div>
        
        <div class="table-container">
            <h2 style="margin-bottom: 20px; color: #232F3E;">💰 Top 5 Services by Cost</h2>
            <table>
                <thead>
                    <tr>
                        <th>Service</th>
                        <th>Cost (30 days)</th>
                        <th>% of Total</th>
                    </tr>
                </thead>
                <tbody>
                    {''.join([f'''
                    <tr>
                        <td>{service}</td>
                        <td>${cost:.2f}</td>
                        <td>{(cost/total_cost*100):.1f}%</td>
                    </tr>
                    ''' for service, cost in top_services])}
                </tbody>
            </table>
        </div>
        
        <div class="status">
            <div class="status-badge {'status-excellent' if compliance_summary['score'] >= 95 and sum(security_metrics.values()) == 0 else 'status-good' if compliance_summary['score'] >= 90 else 'status-warning'}">
                {'✅ EXCELLENT' if compliance_summary['score'] >= 95 and sum(security_metrics.values()) == 0 else '✓ GOOD' if compliance_summary['score'] >= 90 else '⚠️ NEEDS ATTENTION'}
            </div>
        </div>
        
        <footer>
            <p>AWS Enterprise Landing Zone | Monitoring Dashboard</p>
            <p>© 2024 | Generated automatically by Landing Zone reporting tool</p>
        </footer>
    </div>
    
    <script>
        // Cost by Service Chart
        const costCtx = document.getElementById('costChart').getContext('2d');
        new Chart(costCtx, {{
            type: 'bar',
            data: {{
                labels: {json.dumps([s[0] for s in top_services])},
                datasets: [{{
                    label: 'Cost ($)',
                    data: {json.dumps([round(s[1], 2) for s in top_services])},
                    backgroundColor: [
                        'rgba(255, 99, 132, 0.8)',
                        'rgba(54, 162, 235, 0.8)',
                        'rgba(255, 206, 86, 0.8)',
                        'rgba(75, 192, 192, 0.8)',
                        'rgba(153, 102, 255, 0.8)'
                    ]
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: true,
                scales: {{
                    y: {{
                        beginAtZero: true,
                        ticks: {{
                            callback: function(value) {{
                                return '$' + value.toFixed(2);
                            }}
                        }}
                    }}
                }}
            }}
        }});
        
        // Security Findings Chart
        const securityCtx = document.getElementById('securityChart').getContext('2d');
        new Chart(securityCtx, {{
            type: 'doughnut',
            data: {{
                labels: {json.dumps(list(security_metrics.keys()))},
                datasets: [{{
                    data: {json.dumps(list(security_metrics.values()))},
                    backgroundColor: [
                        'rgba(220, 53, 69, 0.8)',
                        'rgba(255, 193, 7, 0.8)',
                        'rgba(23, 162, 184, 0.8)',
                        'rgba(40, 167, 69, 0.8)'
                    ]
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: true
            }}
        }});
        
        // Compliance Chart
        const complianceCtx = document.getElementById('complianceChart').getContext('2d');
        new Chart(complianceCtx, {{
            type: 'pie',
            data: {{
                labels: ['Compliant', 'Non-Compliant'],
                datasets: [{{
                    data: [{compliance_summary['compliant']}, {compliance_summary['non_compliant']}],
                    backgroundColor: [
                        'rgba(40, 167, 69, 0.8)',
                        'rgba(220, 53, 69, 0.8)'
                    ]
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: true
            }}
        }});
    </script>
</body>
</html>
"""
        
        # Write to file
        with open(output_file, 'w') as f:
            f.write(html_content)
        
        print(f"\n✅ Report generated successfully: {output_file}")
        print(f"📊 Open the file in your browser to view the report\n")
        
        return output_file

def main():
    print("\n📊 AWS Landing Zone Report Generator\n")
    print("=" * 70)
    
    try:
        generator = ReportGenerator()
        output_file = 'landing-zone-report.html'
        
        if len(sys.argv) > 1:
            output_file = sys.argv[1]
        
        generator.generate_html_report(output_file)
        
        print(f"\n✅ Report generation complete!")
        print(f"📁 File location: {output_file}")
        print(f"🌐 Open in browser: file://{output_file}")
        
        sys.exit(0)
        
    except Exception as e:
        print(f"\n❌ Error generating report: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
