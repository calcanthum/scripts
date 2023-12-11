#!/bin/bash

# Remote ISO URLs and local ISO filenames
declare -A iso_urls
iso_urls["https://releases.ubuntu.com/18.04.6/ubuntu-18.04.6-desktop-amd64.iso"]="ubuntu18.iso"
iso_urls["https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-desktop-amd64.iso"]="ubuntu20.iso"
iso_urls["https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso"]="ubuntu22.iso"

# Local ISO dir
iso_dir="/vol0/proxmox/template/iso"

# Download remote ISO iff newer than local ISO
function update_iso {
    local url=$1
    local filename=$2
    local local_file="${iso_dir}/${filename}"

    # Fetch last modified date of remote ISO
    last_modified=$(curl -sI $url | grep -i Last-Modified | cut -d' ' -f2-)

    # Compare dates and download iff remote is newer
    if [[ -f "$local_file" ]]; then
        local_date=$(date -r "$local_file" +"%s")
        remote_date=$(date -d "$last_modified" +"%s")
        if [[ $remote_date -gt $local_date ]]; then
            echo "Updating $filename..."
            curl -o "$local_file" -L $url
        else
            echo "$filename is already up to date."
        fi
    else
        echo "Downloading $filename for the first time..."
        curl -o "$local_file" -L $url
    fi
}

# Main loop
for url in "${!iso_urls[@]}"; do
    update_iso "$url" "${iso_urls[$url]}"
done
