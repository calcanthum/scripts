#!/bin/bash

OUTPUT_FILE="ansible_info_$(date +%Y%m%d).txt"
exec > "$OUTPUT_FILE" 2>&1

get_active_ipv4() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+'
}

check_and_write() {
    if [ -e "$1" ]; then
        echo "Contents of $1:"
        if [ -d "$1" ]; then
            ls -lah "$1"
        elif [ -f "$1" ]; then
            cat "$1"
        fi
        echo ""
    else
        echo "$1 does not exist"
        echo ""
    fi
}

echo "Gathering Ansible information..."
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Active IPv4 Addresses:"
get_active_ipv4
echo ""

check_and_write "/etc/ansible"
check_and_write "/etc/ansible/roles"
check_and_write "/etc/ansible/playbooks"
check_and_write "/etc/ansible/ansible.cfg"

echo "Information gathered in $OUTPUT_FILE"
