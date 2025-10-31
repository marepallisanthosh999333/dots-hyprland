#!/bin/bash

# Thermal-based fan activity estimation
# Since direct fan monitoring isn't available, estimate based on temperatures

# Get current temperatures
cpu_temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -nr | head -1)
cpu_temp_c=$((cpu_temp / 1000))

# Temperature thresholds for fan activity estimation
TEMP_IDLE=45
TEMP_LOW=55
TEMP_MEDIUM=65
TEMP_HIGH=75

# Estimate fan activity based on temperature
if [ "$cpu_temp_c" -le "$TEMP_IDLE" ]; then
    fan_activity=0
    fan_status="Idle"
elif [ "$cpu_temp_c" -le "$TEMP_LOW" ]; then
    fan_activity=25
    fan_status="Low"
elif [ "$cpu_temp_c" -le "$TEMP_MEDIUM" ]; then
    fan_activity=50
    fan_status="Medium"
elif [ "$cpu_temp_c" -le "$TEMP_HIGH" ]; then
    fan_activity=75
    fan_status="High"
else
    fan_activity=100
    fan_status="Maximum"
fi

# Store peak activity in a temp file
peak_file="/tmp/quickshell_fan_peak"
if [ -f "$peak_file" ]; then
    peak_activity=$(cat "$peak_file")
    if [ "$fan_activity" -gt "$peak_activity" ]; then
        echo "$fan_activity" > "$peak_file"
        peak_activity=$fan_activity
    fi
else
    echo "$fan_activity" > "$peak_file"
    peak_activity=$fan_activity
fi

echo "Fan Count: 5"
echo "Fan Activity: ${fan_activity}%"
echo "Fan Temperature: ${cpu_temp_c}°C"
echo "Max Activity: ${peak_activity}%"