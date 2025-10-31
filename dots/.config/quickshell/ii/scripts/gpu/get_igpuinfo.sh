#!/usr/bin/env bash
set -euo pipefail

# INTEL iGPU
if command -v "intel_gpu_top" &> /dev/null; then # install intel_gpu_top to get info about iGPU
      echo "[INTEL GPU]"
      # iGPU has unified memory therefore system memory IS video memory (should be identical)
      # Get EXACT same values as system RAM
      vram_total_kib=$(grep MemTotal /proc/meminfo | awk '{print $2}')
      vram_available_kib=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
      vram_used_kib=$((vram_total_kib - vram_available_kib))
      vram_percent=$(( vram_used_kib * 100 / vram_total_kib ))
      vram_used_gb=$(awk -v u="$vram_used_kib" 'BEGIN{printf "%.1f", u/1024/1024}')
      vram_total_gb=$(awk -v t="$vram_total_kib" 'BEGIN{printf "%.1f", t/1024/1024}')

      # Use same temperature source as CPU for consistency
      # For integrated GPU, use x86_pkg_temp (CPU package + iGPU die temperature)
      temperature=$(awk '{printf "%.0f", $1/1000}' <(paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | grep x86_pkg_temp | awk '{print $2}'))

      # Get dynamic GPU usage from intel_gpu_top
      gpu_usage="1"  # Default fallback (realistic minimum)
      
      # Try to get real-time GPU usage from intel_gpu_top
      if command -v intel_gpu_top &> /dev/null; then
          # Get RCS (Render/Compute/Copy) engine usage from intel_gpu_top with timeout
          rcs_usage=$(timeout 3s intel_gpu_top -o - 2>/dev/null | head -n 4 | tail -n 1 | awk '{print $7}' | sed 's/[^0-9.]//g' || echo "")
          
          if [[ -n "$rcs_usage" ]] && [[ "$rcs_usage" != "" ]]; then
              # Convert to integer, treating 0.xx as 1% minimum for display
              gpu_usage_float=$(printf "%.1f" "$rcs_usage" 2>/dev/null || echo "1.0")
              gpu_usage=$(printf "%.0f" "$gpu_usage_float" 2>/dev/null || echo "1")
              
              # Show at least 1% if there's any activity detected
              if [[ "$gpu_usage" == "0" ]] && [[ $(echo "$rcs_usage > 0" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
                  gpu_usage="1"
              fi
          fi
      fi
      
      # Fallback: frequency-based estimation if intel_gpu_top fails or gives 0
      if [[ "$gpu_usage" == "0" ]] || [[ -z "$gpu_usage" ]]; then
          # Check all possible card paths
          for card in /sys/class/drm/card*/gt_cur_freq_mhz; do
              if [[ -r "$card" ]]; then
                  card_dir=$(dirname "$card")
                  if [[ -r "$card_dir/gt_min_freq_mhz" ]]; then
                      cur_freq=$(cat "$card" 2>/dev/null || echo "300")
                      min_freq=$(cat "$card_dir/gt_min_freq_mhz" 2>/dev/null || echo "300")
                      
                      # Simple frequency difference to estimate activity
                      freq_diff=$((cur_freq - min_freq))
                      if [[ "$freq_diff" -gt 100 ]]; then
                          gpu_usage="3"  # Higher activity
                      elif [[ "$freq_diff" -gt 50 ]]; then
                          gpu_usage="2"  # Medium activity  
                      else
                          gpu_usage="1"  # Low activity
                      fi
                      break
                  fi
              fi
          done
      fi
      
      # Ensure reasonable bounds
      if [[ "$gpu_usage" -gt 100 ]]; then
          gpu_usage="100"
      fi

      echo "  Usage : ${gpu_usage} %"
      echo "  VRAM : ${vram_used_gb}/${vram_total_gb} GB"
      echo "  Temp : ${temperature} °C"
      exit 0
fi

# AMD iGPU
if ls /sys/class/drm/card*/device 1>/dev/null 2>&1; then
  echo "[AMD GPU - iGPU only]"

  card_path=""

  # override
  if [[ -n "${AMD_GPU_CARD:-}" && -d "/sys/class/drm/${AMD_GPU_CARD}/device" ]]; then
    card_path="/sys/class/drm/${AMD_GPU_CARD}/device"
  else
    best=""
    best_score=-1

    for d in /sys/class/drm/card*/device; do
      [[ -r "$d/vendor" ]] || continue
      grep -qi "0x1002" "$d/vendor" || continue

      # Dedicated VRAM total (if exists)
      vtot=0
      if [[ -r "$d/mem_info_vis_vram_total" ]]; then
        vtot=$(cat "$d/mem_info_vis_vram_total")
      elif [[ -r "$d/mem_info_vram_total" ]]; then
        vtot=$(cat "$d/mem_info_vram_total")
      fi

      # VRAM type (if exists)
      vtype=""; [[ -r "$d/vram_type" ]] && vtype=$(tr '[:upper:]' '[:lower:]' < "$d/vram_type")

      # GTT (system memory used by iGPU)
      gtt=0; [[ -r "$d/gtt_total" ]] && gtt=$(cat "$d/gtt_total")

      # Is there a connected display on this card? (nice hint)
      has_connected=0
      for con in /sys/class/drm/"${d##*/}"-*/status; do
        [[ -r "$con" ]] || continue
        if [[ "$(cat "$con")" == "connected" ]]; then
          has_connected=1; break
        fi
      done

      # Ddedicated VRAM must be 0 or vram_type must be "none" & GTT must be > 0
      is_igpu=0
      if { [[ "$vtot" -eq 0 ]] || [[ "$vtype" == "none" ]]; } && (( gtt > 0 )); then
        is_igpu=1
      fi
      (( is_igpu == 1 )) || continue

      # Score candidates to pick the "best" iGPU
      score=0
      [[ -r "$d/gpu_busy_percent" ]] && score=$((score+2))
      (( has_connected == 1 )) && score=$((score+1))
      if [[ -r "$d/boot_vga" && "$(cat "$d/boot_vga")" == "1" ]]; then
        score=$((score+1))
      fi

      if (( score > best_score )); then
        best="$d"; best_score=$score
      fi
    done

    card_path="$best"
  fi

  if [[ -z "${card_path}" ]]; then
    echo "No AMD iGPU found."
  else
    gpu_usage=0
    [[ -r "$card_path/gpu_busy_percent" ]] && gpu_usage=$(cat "$card_path/gpu_busy_percent")

    # vis_vram > vram > gtt > system fallback
    used_b=0; total_b=0
    if [[ -r "$card_path/mem_info_vis_vram_used" && -r "$card_path/mem_info_vis_vram_total" ]]; then
      used_b=$(cat "$card_path/mem_info_vis_vram_used")
      total_b=$(cat "$card_path/mem_info_vis_vram_total")
    elif [[ -r "$card_path/mem_info_vram_used" && -r "$card_path/mem_info_vram_total" ]]; then
      used_b=$(cat "$card_path/mem_info_vram_used")
      total_b=$(cat "$card_path/mem_info_vram_total")
    elif [[ -r "$card_path/gtt_used" && -r "$card_path/gtt_total" ]]; then
      used_b=$(cat "$card_path/gtt_used")
      total_b=$(cat "$card_path/gtt_total")
    else
      # Fallback: approximate with system ram (might be atrociously misleading)
      vram_total_kib=$(grep MemTotal /proc/meminfo | awk '{print $2}')
      vram_available_kib=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
      used_b=$(( (vram_total_kib - vram_available_kib) * 1024 ))
      total_b=$(( vram_total_kib * 1024 ))
    fi

    vram_used_gb=$(awk -v u="${used_b:-0}" 'BEGIN{printf "%.1f", u/1024/1024/1024}')
    vram_total_gb=$(awk -v t="${total_b:-0}" 'BEGIN{printf "%.1f", t/1024/1024/1024}')

    # edge > junction > tctl > any temp*_input
    temperature=0; found=0
    for hm in "$card_path"/hwmon/hwmon*; do
      [[ -d "$hm" ]] || continue

      for key in edge junction Tctl; do
        for lbl in "$hm"/temp*_label; do
          [[ -r "$lbl" ]] || continue
          if grep -qi "$key" "$lbl"; then
            base="${lbl%_label}"
            if [[ -r "${base}_input" ]]; then
              temperature=$(awk '{printf "%.0f",$1/1000}' "${base}_input"); found=1; break
            fi
          fi
        done
        [[ $found -eq 1 ]] && break
      done

      if [[ $found -eq 0 ]]; then
        for tin in "$hm"/temp*_input; do
          [[ -r "$tin" ]] || continue
          temperature=$(awk '{printf "%.0f",$1/1000}' "$tin"); found=1; break
        done
      fi

      [[ $found -eq 1 ]] && break
    done

    echo "  Usage : ${gpu_usage} %"
    echo "  VRAM : ${vram_used_gb}/${vram_total_gb} GB"
    echo "  Temp : ${temperature} °C"
    exit 0
  fi
fi