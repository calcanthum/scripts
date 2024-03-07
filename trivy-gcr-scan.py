import subprocess
import json
import sys

def run_command(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return None, result.stderr
    return json.loads(result.stdout), None

def is_registry_public(registry):
    _, error = run_command(['gcloud', 'container', 'images', 'list', '--repository', f'gcr.io/{registry}', '--format', 'json'])
    return error is None

def get_authenticated_accounts():
    accounts, _ = run_command(['gcloud', 'auth', 'list', '--format', 'json'])
    if accounts is None:
        return []
    return [account['account'] for account in accounts if account.get('status') == 'ACTIVE']

def get_gcr_images(registry):
    images, _ = run_command(['gcloud', 'container', 'images', 'list', '--repository', f'gcr.io/{registry}', '--format', 'json'])
    if images is None:
        return []
    return [image['name'] for image in images]

def scan_image_with_trivy(image, verbose=False):
    if verbose:
        cmd = ['trivy', '--quiet', 'image', '--severity', 'CRITICAL,HIGH,MEDIUM,LOW', image]
    else:
        cmd = ['trivy', '--quiet', 'image', '--severity', 'CRITICAL,HIGH,MEDIUM,LOW', '--format', 'json', image]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if not result.stdout.strip():
        print("No results from Trivy scan.")
        return

    if result.returncode != 0:
        print(f"Failed to scan image: {result.stderr}. Ensure Trivy is installed and has the necessary permissions.")
        exit(1)

    if verbose:
        print(result.stdout)
    else:
        vulnerabilities = json.loads(result.stdout)
        summary = {'CRITICAL': {'count': 0, 'cves': []}, 'HIGH': {'count': 0}, 'MEDIUM': {'count': 0}, 'LOW': {'count': 0}}

        for result in vulnerabilities.get('Results', []):
            if 'Vulnerabilities' in result:
                for vuln in result['Vulnerabilities']:
                    severity = vuln['Severity']
                    summary[severity]['count'] += 1
                    if severity == 'CRITICAL':
                        summary[severity]['cves'].append(vuln['VulnerabilityID'])

        for severity, data in summary.items():
            print(f"{severity}: {data['count']} vulnerabilities")
            if severity == 'CRITICAL' and data['cves']:
                print(f"Critical CVEs: {', '.join(data['cves'])}")

def main():
    registry_input = input("Enter your registry suffix (e.g., for gcr.io/my-project, enter 'my-project'): ")
    if is_registry_public(registry_input):
        print("Registry is publicly accessible. Proceeding without authentication...")
    else:
        accounts = get_authenticated_accounts()
        if not accounts:
            print("No authenticated accounts found and the registry is not publicly accessible. Please authenticate using 'gcloud auth login'")
            sys.exit(1)
        
        print("Authenticated accounts found:")
        for i, account in enumerate(accounts, start=1):
            print(f"{i}. {account}")
        
        selected_account_index = int(input("Select an account to use (enter number): ")) - 1
        selected_account = accounts[selected_account_index]
        print(f"Selected account: {selected_account}")
    
    images = get_gcr_images(registry_input)
    
    if not images:
        print("No images found in the specified registry.")
        return
    
    verbose_input = input("Would you like a detailed scan report? (yes/no): ").lower()
    verbose = verbose_input in ["yes", "y"]
    
    for image in images:
        print(f"Scanning {image}...")
        scan_image_with_trivy(image, verbose)

if __name__ == "__main__":
    main()
