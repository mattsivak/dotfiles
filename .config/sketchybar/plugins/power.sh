#!/bin/sh

SKETCHYBAR=/opt/homebrew/bin/sketchybar
JQ=/usr/bin/jq
BC=/usr/bin/bc

DATA=$(/usr/local/bin/mac_power_monitor 2>/dev/null)
if [ -z "$DATA" ]; then
  $SKETCHYBAR --set power_cpu drawing=off \
    --set power_gpu drawing=off \
    --set power_ane drawing=off \
    --set power_display drawing=off \
    --set power_charging drawing=off \
    --set power_adapter drawing=off \
    --set power_system drawing=off
  exit 0
fi

CPU_WATTS=$(echo "$DATA" | $JQ -r '.cpu_watts')
GPU_WATTS=$(echo "$DATA" | $JQ -r '.gpu_watts')
ANE_WATTS=$(echo "$DATA" | $JQ -r '.ane_watts')
DISPLAY_WATTS=$(echo "$DATA" | $JQ -r '.display_watts')
SYSTEM_WATTS=$(echo "$DATA" | $JQ -r '.system_watts')
CHARGING_WATTS=$(echo "$DATA" | $JQ -r '.battery.charging_watts')
ADAPTER_WATTS=$(echo "$DATA" | $JQ -r '.battery.adapter_watts')
DELIVERY_WATTS=$(echo "$DATA" | $JQ -r '.charger.delivery_watts')

# CPU widget - show when > 2W
if [ "$(echo "$CPU_WATTS > 1" | $BC -l)" -eq 1 ]; then
  $SKETCHYBAR --set power_cpu drawing=on label="$(printf '%.1f' "$CPU_WATTS")W"
else
  $SKETCHYBAR --set power_cpu drawing=off
fi

# GPU widget - show when > 2W
if [ "$(echo "$GPU_WATTS > 1" | $BC -l)" -eq 1 ]; then
  $SKETCHYBAR --set power_gpu drawing=on label="$(printf '%.1f' "$GPU_WATTS")W"
else
  $SKETCHYBAR --set power_gpu drawing=off
fi

# ANE widget - show when > 2W
if [ "$(echo "$ANE_WATTS > 1" | $BC -l)" -eq 1 ]; then
  $SKETCHYBAR --set power_ane drawing=on label="$(printf '%.1f' "$ANE_WATTS")W"
else
  $SKETCHYBAR --set power_ane drawing=off
fi

# Display widget - show when > 1W
if [ "$DISPLAY_WATTS" != "null" ] && [ "$(echo "$DISPLAY_WATTS > 1" | $BC -l)" -eq 1 ]; then
  $SKETCHYBAR --set power_display drawing=on label="$(printf '%.1f' "$DISPLAY_WATTS")W"
else
  $SKETCHYBAR --set power_display drawing=off
fi

# Charging rate - show when > 1W or < -1W
if [ "$(echo "$CHARGING_WATTS > 1" | $BC -l)" -eq 1 ] || [ "$(echo "$CHARGING_WATTS < -1" | $BC -l)" -eq 1 ]; then
  if [ "$(echo "$CHARGING_WATTS > 0" | $BC -l)" -eq 1 ]; then
    $SKETCHYBAR --set power_charging drawing=on icon="󰂄" label="+$(printf '%.0f' "$CHARGING_WATTS")W"
  else
    $SKETCHYBAR --set power_charging drawing=on icon="󰂃" label="$(printf '%.0f' "$CHARGING_WATTS")W"
  fi
else
  $SKETCHYBAR --set power_charging drawing=off
fi

# Adapter watts - show when connected
if [ "$ADAPTER_WATTS" != "null" ] && [ -n "$ADAPTER_WATTS" ]; then
  $SKETCHYBAR --set power_adapter drawing=on icon="󰚥" label="$(printf '%.0f' "$DELIVERY_WATTS")W"
else
  $SKETCHYBAR --set power_adapter drawing=off
fi

# System total - show only when no single value represents consumption
if [ "$(echo "$CHARGING_WATTS > 1" | $BC -l)" -eq 1 ] || { [ "$(echo "$CHARGING_WATTS < -1" | $BC -l)" -eq 1 ] && [ "$(echo "$DELIVERY_WATTS > 1" | $BC -l)" -eq 1 ]; }; then
  $SKETCHYBAR --set power_system drawing=on icon="󱐋" label="$(printf '%.0f' "$SYSTEM_WATTS")W"
else
  $SKETCHYBAR --set power_system drawing=off
fi

# Update popup data for all power widgets
OTHER_WATTS=$(echo "$DATA" | $JQ -r '.other_watts')
CHARGE_PCT=$(echo "$DATA" | $JQ -r '.battery.charge_percent')
IS_CHARGING=$(echo "$DATA" | $JQ -r '.battery.is_charging')
TIME_REMAINING=$(echo "$DATA" | $JQ -r '.battery.time_remaining_min')

# Calculate percentages
if [ "$(echo "$SYSTEM_WATTS > 0" | $BC -l)" -eq 1 ]; then
  CPU_PCT=$(echo "scale=0; $CPU_WATTS * 100 / $SYSTEM_WATTS" | $BC)
  GPU_PCT=$(echo "scale=0; $GPU_WATTS * 100 / $SYSTEM_WATTS" | $BC)
  ANE_PCT=$(echo "scale=0; $ANE_WATTS * 100 / $SYSTEM_WATTS" | $BC)
  DISPLAY_PCT=$(echo "scale=0; $DISPLAY_WATTS * 100 / $SYSTEM_WATTS" | $BC 2>/dev/null || echo 0)
  OTHER_PCT=$(echo "scale=0; $OTHER_WATTS * 100 / $SYSTEM_WATTS" | $BC)
else
  CPU_PCT=0
  GPU_PCT=0
  ANE_PCT=0
  DISPLAY_PCT=0
  OTHER_PCT=0
fi

# Extract CPU cluster data
E_CLUSTER_FREQ=$(echo "$DATA" | $JQ -r '.cpu_clusters[0].freq_mhz // empty')
E_CLUSTER_ACTIVE=$(echo "$DATA" | $JQ -r '.cpu_clusters[0].active_percent // empty')
P0_CLUSTER_FREQ=$(echo "$DATA" | $JQ -r '.cpu_clusters[1].freq_mhz // empty')
P0_CLUSTER_ACTIVE=$(echo "$DATA" | $JQ -r '.cpu_clusters[1].active_percent // empty')
P1_CLUSTER_FREQ=$(echo "$DATA" | $JQ -r '.cpu_clusters[2].freq_mhz // empty')
P1_CLUSTER_ACTIVE=$(echo "$DATA" | $JQ -r '.cpu_clusters[2].active_percent // empty')

# Determine status
if [ "$IS_CHARGING" = "true" ]; then
  STATUS="Charging"
  STATUS_ICON="󰂄"
elif [ "$(echo "$CHARGING_WATTS < -1" | $BC -l)" -eq 1 ]; then
  STATUS="Discharging"
  STATUS_ICON="󰂃"
else
  STATUS="Idle"
  STATUS_ICON="󰁹"
fi

# Flow label
if [ "$(echo "$CHARGING_WATTS > 0" | $BC -l)" -eq 1 ]; then
  FLOW_ICON="󰂄"
  FLOW_LABEL="+$(printf '%.1f' "$CHARGING_WATTS")W"
else
  FLOW_ICON="󰂃"
  FLOW_LABEL="$(printf '%.1f' "$CHARGING_WATTS")W"
fi

# Update popups for all power widgets
for PARENT in power_system power_adapter power_charging power_cpu power_gpu power_ane power_display; do
  $SKETCHYBAR --set ${PARENT}_pp_system label="System: $(printf '%.1f' "$SYSTEM_WATTS")W" \
              --set ${PARENT}_pp_cpu label="CPU: $(printf '%.1f' "$CPU_WATTS")W (${CPU_PCT}%)" \
              --set ${PARENT}_pp_gpu label="GPU: $(printf '%.1f' "$GPU_WATTS")W (${GPU_PCT}%)" \
              --set ${PARENT}_pp_ane label="ANE: $(printf '%.2f' "$ANE_WATTS")W (${ANE_PCT}%)" \
              --set ${PARENT}_pp_other label="Other: $(printf '%.1f' "$OTHER_WATTS")W (${OTHER_PCT}%)" \
              --set ${PARENT}_pp_charge label="Charge: $(printf '%.0f' "$CHARGE_PCT")%" \
              --set ${PARENT}_pp_flow icon="$FLOW_ICON" label="Flow: $FLOW_LABEL" \
              --set ${PARENT}_pp_status icon="$STATUS_ICON" label="Status: $STATUS"

  # Display watts
  if [ "$DISPLAY_WATTS" != "null" ] && [ -n "$DISPLAY_WATTS" ]; then
    $SKETCHYBAR --set ${PARENT}_pp_display label="Display: $(printf '%.1f' "$DISPLAY_WATTS")W (${DISPLAY_PCT}%)"
  else
    $SKETCHYBAR --set ${PARENT}_pp_display label="Display: --"
  fi

  # CPU Clusters
  if [ -n "$E_CLUSTER_FREQ" ]; then
    $SKETCHYBAR --set ${PARENT}_pp_ecluster label="E-Cluster: $(printf '%.0f' "$E_CLUSTER_FREQ")MHz ($(printf '%.0f' "$E_CLUSTER_ACTIVE")%)" \
                --set ${PARENT}_pp_p0cluster label="P0-Cluster: $(printf '%.0f' "$P0_CLUSTER_FREQ")MHz ($(printf '%.0f' "$P0_CLUSTER_ACTIVE")%)" \
                --set ${PARENT}_pp_p1cluster label="P1-Cluster: $(printf '%.0f' "$P1_CLUSTER_FREQ")MHz ($(printf '%.0f' "$P1_CLUSTER_ACTIVE")%)"
  fi

  # Time remaining - show only when available
  if [ "$TIME_REMAINING" != "null" ] && [ -n "$TIME_REMAINING" ]; then
    $SKETCHYBAR --set ${PARENT}_pp_time drawing=on label="Time: ${TIME_REMAINING}min"
  else
    $SKETCHYBAR --set ${PARENT}_pp_time drawing=off
  fi

  # Adapter section
  if [ "$ADAPTER_WATTS" != "null" ] && [ -n "$ADAPTER_WATTS" ]; then
    $SKETCHYBAR --set ${PARENT}_pp_header_adapter drawing=on \
                --set ${PARENT}_pp_adapter drawing=on label="Adapter: ${ADAPTER_WATTS}W"
    if [ "$DELIVERY_WATTS" != "null" ] && [ -n "$DELIVERY_WATTS" ]; then
      $SKETCHYBAR --set ${PARENT}_pp_delivery drawing=on label="Delivery: $(printf '%.0f' "$DELIVERY_WATTS")W"
    else
      $SKETCHYBAR --set ${PARENT}_pp_delivery drawing=off
    fi
  else
    $SKETCHYBAR --set ${PARENT}_pp_header_adapter drawing=off \
                --set ${PARENT}_pp_adapter drawing=off \
                --set ${PARENT}_pp_delivery drawing=off
  fi
done
