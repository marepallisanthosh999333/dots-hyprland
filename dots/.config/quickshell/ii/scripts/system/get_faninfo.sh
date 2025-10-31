#!/bin/bash

# Fan monitoring script for QuickShell Resources
# Monitors actual hardware fans via thermal cooling devices

# Check for actual fan devices
fan_devices=()
for i in {0..20}; do
    device_path="/sys/class/thermal/cooling_device$i"
    if [ -f "$device_path/type" ]; then
        device_type=$(cat "$device_path/type" 2>/dev/null)
        if [ "$device_type" = "Fan" ]; then
            fan_devices+=("$i")
        fi
    fi
done

if [ ${#fan_devices[@]} -eq 0 ]; then
    echo "No fans found"
    exit 1
fi

# Get fan states and max states
total_activity=0
active_fans=0
max_activity=0

for fan_id in "${fan_devices[@]}"; do
    cur_state=$(cat "/sys/class/thermal/cooling_device$fan_id/cur_state" 2>/dev/null || echo "0")
    max_state=$(cat "/sys/class/thermal/cooling_device$fan_id/max_state" 2>/dev/null || echo "1")
    
    if [ "$max_state" -gt 0 ]; then
        fan_percent=$((cur_state * 100 / max_state))
        total_activity=$((total_activity + fan_percent))
        active_fans=$((active_fans + 1))
        
        if [ "$fan_percent" -gt "$max_activity" ]; then
            max_activity="$fan_percent"
        fi
    fi
done

# Calculate average fan activity
if [ "$active_fans" -gt 0 ]; then
    avg_activity=$((total_activity / active_fans))
else
    avg_activity=0
fi

# Get max temperature for correlation
max_temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -nr | head -1)
max_temp_c=$((max_temp / 1000))

# Determine fan status
if [ "$avg_activity" -eq 0 ]; then
    fan_status="Idle"
elif [ "$avg_activity" -lt 25 ]; then
    fan_status="Low"
elif [ "$avg_activity" -lt 60 ]; then
    fan_status="Medium"
else
    fan_status="High"
fi

echo "Fan Count: ${#fan_devices[@]}"
echo "Fan Activity: ${avg_activity}%"
echo "Fan Temperature: ${max_temp_c}°C"
echo "Max Activity: ${max_activity}%"
