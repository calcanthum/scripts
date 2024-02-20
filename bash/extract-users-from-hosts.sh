#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

current_host=""

while IFS= read -r line; do
    if [[ $line == ok:* ]]; then
        current_host=$(echo "$line" | sed -E 's/ok: \[(.*)\] =>.*/\1/')
        echo $current_host
    elif [[ $line == *".ssh/authorized_keys"* ]]; then
        username=$(echo "$line" | sed -E 's/.*\/home\/([^\/]+)\/.*/\1/')
        echo $username
    fi
done < "$input_file"
