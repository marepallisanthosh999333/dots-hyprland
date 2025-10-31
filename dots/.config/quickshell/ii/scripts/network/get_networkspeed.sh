#!/usr/bin/env bash
set -euo pipefail

# Network Speed Monitoring Script
# Added for download/upload speed monitoring - Custom modification
# This script monitors network interface speeds in bytes per second

# Find the active network interface (excluding loopback)
INTERFACE=""
for iface in $(ls /sys/class/net/ | grep -v lo); do
    if [[ -f "/sys/class/net/$iface/operstate" ]]; then
        state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo "down")
        if [[ "$state" == "up" ]]; then
            # Prefer wireless interfaces, then ethernet
            if [[ "$iface" =~ ^(wl|wlan) ]]; then
                INTERFACE="$iface"
                break
            elif [[ "$iface" =~ ^(en|eth) ]] && [[ -z "$INTERFACE" ]]; then
                INTERFACE="$iface"
            fi
        fi
    fi
done

# Fallback to first active interface if no preferred found
if [[ -z "$INTERFACE" ]]; then
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        if [[ -f "/sys/class/net/$iface/operstate" ]]; then
            state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo "down")
            if [[ "$state" == "up" ]]; then
                INTERFACE="$iface"
                break
            fi
        fi
    done
fi

if [[ -z "$INTERFACE" ]]; then
    echo "No active network interface found"
    exit 1
fi

# Network speed calculation requires two measurements
STATS_FILE="/sys/class/net/$INTERFACE/statistics"
CACHE_FILE="/tmp/quickshell_network_${INTERFACE}.cache"

if [[ ! -r "$STATS_FILE/rx_bytes" || ! -r "$STATS_FILE/tx_bytes" ]]; then
    echo "Cannot read network statistics for $INTERFACE"
    exit 1
fi

# Current measurements
current_time=$(date +%s)
current_rx=$(cat "$STATS_FILE/rx_bytes")
current_tx=$(cat "$STATS_FILE/tx_bytes")

# Initialize or read previous measurements
if [[ -f "$CACHE_FILE" ]]; then
    IFS=' ' read -r prev_time prev_rx prev_tx < "$CACHE_FILE"
else
    # First run - create cache file and return zero speeds
    echo "$current_time $current_rx $current_tx" > "$CACHE_FILE"
    echo "Interface: $INTERFACE"
    echo "  Download: 0 B/s"
    echo "  Upload: 0 B/s"
    echo "  Total: 0 B/s"
    exit 0
fi

# Calculate time difference
time_diff=$((current_time - prev_time))

# Avoid division by zero
if [[ "$time_diff" -le 0 ]]; then
    time_diff=1
fi

# Calculate speeds (bytes per second)
rx_speed=$(( (current_rx - prev_rx) / time_diff ))
tx_speed=$(( (current_tx - prev_tx) / time_diff ))
total_speed=$((rx_speed + tx_speed))

# Handle counter rollover (unlikely but possible)
if [[ "$rx_speed" -lt 0 ]]; then rx_speed=0; fi
if [[ "$tx_speed" -lt 0 ]]; then tx_speed=0; fi

# Update cache file
echo "$current_time $current_rx $current_tx" > "$CACHE_FILE"

# Output results
echo "Interface: $INTERFACE"
echo "  Download: $rx_speed B/s"
echo "  Upload: $tx_speed B/s"
echo "  Total: $total_speed B/s"