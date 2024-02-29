import subprocess
import json
import argparse
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

grype_to_trivy_status_map = {
    "fixed": "fixed",
    "not-fixed": "affected",
    "wont-fix": "will_not_fix",
    "unknown": "unknown",
}

def run_scan(command):
    try:
        result = subprocess.check_output(command, stderr=subprocess.PIPE, text=True)
        return json.loads(result)
    except subprocess.CalledProcessError as e:
        logging.error(f"Error running command {' '.join(command)}: {e.stderr}")
        raise

def extract_cves(report, scanner):
    cves = {}
    if scanner == "trivy":
        for result in report.get('Results', []):
            for vuln in result.get('Vulnerabilities', []):
                cve_id = vuln.get('VulnerabilityID')
                status = vuln.get('Status', 'unknown')
                cves[cve_id] = status
    elif scanner == "grype":
        for match in report.get('matches', []):
            cve_id = match.get('vulnerability', {}).get('id')
            state = match.get('vulnerability', {}).get('fix', {}).get('state', 'unknown')
            status = grype_to_trivy_status_map.get(state, 'unknown')
            cves[cve_id] = status
    return cves

def compare_cves(trivy_cves, grype_cves, verbose):
    trivy_cve_ids = set(trivy_cves.keys())
    grype_cve_ids = set(grype_cves.keys())

    common_cves = trivy_cve_ids & grype_cve_ids
    unique_to_trivy = trivy_cve_ids - grype_cve_ids
    unique_to_grype = grype_cve_ids - trivy_cve_ids

    matching_fix_status = {cve for cve in common_cves if trivy_cves[cve] == grype_cves[cve]}
    mismatch_fix_status = common_cves - matching_fix_status

    logging.info(f"Common CVEs with matching fix statuses: {len(matching_fix_status)}")
    if verbose:
        for cve in sorted(matching_fix_status):
            status = trivy_cves[cve]
            logging.info(f"{cve}: {status}")

    logging.info(f"Common CVEs with mismatched fix statuses: {len(mismatch_fix_status)}")
    if verbose:
        for cve in sorted(mismatch_fix_status):
            trivy_status = trivy_cves[cve]
            grype_status = grype_cves[cve]
            logging.info(f"{cve}: Trivy={trivy_status}, Grype={grype_status}")

    logging.info(f"Unique to Trivy: {len(unique_to_trivy)}")
    if verbose:
        logging.info("CVEs unique to Trivy: " + ", ".join(sorted(unique_to_trivy)))

    logging.info(f"Unique to Grype: {len(unique_to_grype)}")
    if verbose:
        logging.info("CVEs unique to Grype: " + ", ".join(sorted(unique_to_grype)))

def process_image(image, verbose):
    image += ":latest" if ":" not in image else ""
    logging.info(f"\nScanning {image}...")
    trivy_command = ["trivy", "image", "--format", "json", image]
    grype_command = ["grype", image, "-o", "json"]

    try:
        trivy_report = run_scan(trivy_command)
        grype_report = run_scan(grype_command)
        trivy_cves = extract_cves(trivy_report, "trivy")
        grype_cves = extract_cves(grype_report, "grype")
        compare_cves(trivy_cves, grype_cves, verbose)
    except Exception as e:
        logging.error(f"Failed to run scans for image: {image}. Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compare CVEs found in container images by Trivy and Grype.")
    parser.add_argument("images", nargs='+', help="Names of the container images to scan")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output")
    args = parser.parse_args()

    for image in args.images:
        process_image(image, args.verbose)
