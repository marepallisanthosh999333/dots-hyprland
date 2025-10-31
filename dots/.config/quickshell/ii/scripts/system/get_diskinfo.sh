#!/bin/bash

# Disk usage monitoring script for QuickShell Resources
# Simple format for easy QML parsing

# Get disk usage for mounted filesystems, excluding temporary/virtual filesystems
df -h | grep -E '^/dev/' | grep -v '/snap/' | while read filesystem size used avail percent mountpoint; do
    # Clean up the percentage (remove %)
    percent_num=$(echo "$percent" | sed 's/%//')
    
    # Format mount point for display (show / as "Root", others as folder name)
    if [ "$mountpoint" = "/" ]; then
        display_name="Root"
    else
        display_name=$(basename "$mountpoint")
    fi
    
    # Output in simple key:value format
    echo "Partition:$display_name:$used:$size:$percent_num"
done

# Get main disk device name
main_disk=$(lsblk -ndo NAME | head -1)
echo "MainDisk:$main_disk"