#!/bin/bash

execute_command() {
    local output
    output=$(eval "$1" 2>&1)
    echo "$output"
}

check_registry_accessibility() {
    local registry="$1"
    local result
    result=$(execute_command "gcloud container images list --repository=gcr.io/${registry} --format=json")
    [[ $result == *"ERROR"* ]] && return 1 || return 0
}

list_active_gcloud_accounts() {
    local accounts
    accounts=$(execute_command "gcloud auth list --format=json")
    echo $accounts | jq -r '.[] | select(.status == "ACTIVE") | .account'
}

list_gcr_repository_images() {
    local registry="$1"
    local images
    images=$(execute_command "gcloud container images list --repository=gcr.io/${registry} --format=json")
    echo $images | jq -r '.[] | .name'
}

scan_container_image() {
    local image="$1"
    local detailed_report="$2"
    local result

    if [[ $detailed_report == "true" ]]; then
        result=$(trivy --quiet image --severity CRITICAL,HIGH,MEDIUM,LOW "$image")
        echo "$result"
    else
        result=$(trivy --quiet image --severity CRITICAL,HIGH,MEDIUM,LOW --format json "$image")
        if echo "$result" | jq '.Results[] | .Vulnerabilities' | grep -qv 'null'; then
            echo "CRITICAL vulnerabilities found:"
            echo "$result" | jq -r '.Results[] | .Vulnerabilities[] | select(.Severity == "CRITICAL") | "\(.VulnerabilityID) (\(.Severity))"'
            echo "Summary counts by severity:"
            echo "$result" | jq -r '.Results[] | .Vulnerabilities[] | .Severity' | sort | uniq -c | awk '{print $2": "$1" vulnerabilities"}'
        else
            echo "No vulnerabilities found."
        fi
    fi
}

main() {
    read -p "Enter your registry suffix (e.g., 'my-project' for gcr.io/my-project): " registry_suffix
    if check_registry_accessibility "$registry_suffix"; then
        echo "Registry is publicly accessible. Proceeding without authentication..."
    else
        mapfile -t authenticated_accounts < <(list_active_gcloud_accounts)
        if [ ${#authenticated_accounts[@]} -eq 0 ]; then
            echo "No authenticated accounts found. Registry is not publicly accessible. Please authenticate with 'gcloud auth login'."
            exit 1
        fi
        
        echo "Authenticated accounts found. Please select an account to use:"
        for i in "${!authenticated_accounts[@]}"; do
            echo "$((i+1)). ${authenticated_accounts[i]}"
        done
        
        read -p "Select an account by number: " account_selection
        selected_account="${authenticated_accounts[$((account_selection-1))]}"
        echo "Using account: $selected_account"
    fi
    
    mapfile -t images < <(list_gcr_repository_images "$registry_suffix")
    if [ ${#images[@]} -eq 0 ]; then
        echo "No images found in specified registry."
        return
    fi
    
    read -p "Detailed scan report? (yes/no): " detailed_reply
    detailed_scan="false"
    [[ "$detailed_reply" == "yes" || "$detailed_reply" == "y" ]] && detailed_scan="true"
    
    for image in "${images[@]}"; do
        echo "Scanning image: $image"
        scan_container_image "$image" "$detailed_scan"
    done
}

main
