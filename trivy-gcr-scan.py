import subprocess
import json
import sys

def execute_subprocess_command(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return json.loads(result.stdout), None
    except subprocess.CalledProcessError as e:
        return None, e.stderr

def check_registry_accessibility(registry):
    _, error = execute_subprocess_command(['gcloud', 'container', 'images', 'list', '--repository', f'gcr.io/{registry}', '--format', 'json'])
    return error is None

def list_active_gcloud_accounts():
    accounts, _ = execute_subprocess_command(['gcloud', 'auth', 'list', '--format', 'json'])
    if accounts is None:
        return []
    return [account['account'] for account in accounts if account.get('status') == 'ACTIVE']

def list_gcr_repository_images(registry):
    images, _ = execute_subprocess_command(['gcloud', 'container', 'images', 'list', '--repository', f'gcr.io/{registry}', '--format', 'json'])
    if images is None:
        return []
    return [image['name'] for image in images]

def scan_container_image(image, detailed_report=False):
    command = ['trivy', '--quiet', 'image', '--severity', 'CRITICAL,HIGH,MEDIUM,LOW', image]
    if not detailed_report:
        command.append('--format')
        command.append('json')
    
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        
        if not result.stdout.strip():
            print("No results from Trivy scan.")
            return
        
        if detailed_report:
            print(result.stdout)
        else:
            vulnerabilities = json.loads(result.stdout)
            summarize_vulnerabilities(vulnerabilities)
    except subprocess.CalledProcessError as e:
        print(f"Failed to scan image: {e.stderr}. Ensure Trivy is installed and has the necessary permissions.")
        sys.exit(1)

def summarize_vulnerabilities(vulnerabilities):
    summary = {'CRITICAL': {'count': 0, 'cves': []}, 'HIGH': {'count': 0}, 'MEDIUM': {'count': 0}, 'LOW': {'count': 0}}
    
    for result in vulnerabilities.get('Results', []):
        for vuln in result.get('Vulnerabilities', []):
            severity = vuln['Severity']
            summary[severity]['count'] += 1
            if severity == 'CRITICAL':
                summary[severity]['cves'].append(vuln['VulnerabilityID'])
                
    for severity, data in summary.items():
        print(f"{severity}: {data['count']} vulnerabilities")
        if severity == 'CRITICAL' and data['cves']:
            print(f"Critical CVEs: {', '.join(data['cves'])}")

def main():
    registry_suffix = input("Enter your registry suffix (e.g., 'my-project' for gcr.io/my-project): ")
    if check_registry_accessibility(registry_suffix):
        print("Registry is publicly accessible. Proceeding without authentication...")
    else:
        authenticated_accounts = list_active_gcloud_accounts()
        if not authenticated_accounts:
            print("No authenticated accounts found. Registry is not publicly accessible. Please authenticate with 'gcloud auth login'.")
            sys.exit(1)
        
        print("Authenticated accounts found. Please select an account to use:")
        for index, account in enumerate(authenticated_accounts, start=1):
            print(f"{index}. {account}")
        
        account_selection = int(input("Select an account by number: ")) - 1
        print(f"Using account: {authenticated_accounts[account_selection]}")
    
    images = list_gcr_repository_images(registry_suffix)
    if not images:
        print("No images found in specified registry.")
        return
    
    detailed_scan = input("Detailed scan report? (yes/no): ").strip().lower() in ["yes", "y"]
    
    for image in images:
        print(f"Scanning image: {image}")
        scan_container_image(image, detailed_scan)

if __name__ == "__main__":
    main()
