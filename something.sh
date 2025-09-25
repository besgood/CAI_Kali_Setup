#!/bin/bash

# SSH KEX Error Filter - Simple Version
# Filters out IPs with SSH key exchange errors

# Ask for input file
read -p "Enter the filename containing IPs: " ip_file

# Check if input file exists
if [ ! -f "$ip_file" ]; then
    echo "Error: $ip_file not found"
    exit 1
fi

echo "Testing SSH compatibility on IPs from $ip_file..."

# Clean output files
> ssh_compatible.txt
> ssh_kex_errors.txt

total_ips=$(wc -l < "$ip_file")
current=0

while IFS= read -r ip; do
    current=$((current + 1))
    printf "Testing %d/%d: %s ... " "$current" "$total_ips" "$ip"
    
    # Test SSH handshake
    ssh_result=$(timeout 8 ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no \
                 -o PreferredAuthentications=none "$ip" 2>&1)
    
    if echo "$ssh_result" | grep -qE "(key exchange|Unable to negotiate|no matching|algorithm|protocol version)"; then
        echo "$ip" >> ssh_kex_errors.txt
        echo "KEX Error"
    else
        echo "$ip" >> ssh_compatible.txt  
        echo "OK"
    fi
done < "$ip_file"

echo ""
echo "Results:"
echo "Compatible IPs: $(wc -l < ssh_compatible.txt) (saved to ssh_compatible.txt)"
echo "KEX Error IPs:  $(wc -l < ssh_kex_errors.txt) (saved to ssh_kex_errors.txt)"
echo ""
echo "Use ssh_compatible.txt for your NetExec scan"
