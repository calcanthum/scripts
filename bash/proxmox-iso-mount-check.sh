#!/bin/bash

# Local ISO dir
iso_dir="/vol0/proxmox/template/iso"

# ISO checking function
function check_mounted_iso {
    local iso_file=$1
    local vmid=$2

    # Get VM info
    vm_config=$(qm config $vmid)

    # Is ISO mounted on VM?
    if echo "$vm_config" | grep -q "$iso_file"; then
        echo "ISO $iso_file is mounted on VM $vmid"
    fi
}

# Main loop
function main {
    for iso_file in $iso_dir/*.iso; do
        for vmid in $(qm list | awk '{if(NR>1) print $1}'); do
            check_mounted_iso "$iso_file" "$vmid"
        done
    done
}
main
