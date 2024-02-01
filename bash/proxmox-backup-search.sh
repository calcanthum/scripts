#!/bin/bash

read -p "Enter the old VM name: " vm_name

backup_file="backups.$(date +"%Y-%m-%d-%T").txt"
notes_file="notes.$(date +"%Y-%m-%d-%T").txt"

proxmox-backup-client snapshot list --repository proxmox > "$backup_file"

for s in $(awk '{print $2}' "$backup_file" ); do 
    proxmox-backup-client snapshot notes show $s --repository proxmox 2>/dev/null 
done >> "$notes_file"

vmid=$(grep -i "$vm_name" "$notes_file" | awk -F, '{print $1}' | uniq)

if [ -z "$vmid" ]; then
    echo "VMID not found for $vm_name."
    exit 1
else
    echo "VMID for $vm_name is $vmid."
fi

grep "$vmid" "$backup_file"
