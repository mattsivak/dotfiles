#!/bin/sh
#
# Fills and toggles the power widget's popup.
#
# Runs on click only, so it can afford system_profiler (~85ms) alongside ioreg
# (~13ms). Nothing here is on a timer.
#
# Battery health is read from system_profiler rather than computed from ioreg
# capacities: macOS reports 90% where NominalChargeCapacity/DesignCapacity
# gives 87.5% and AppleRawMaxCapacity/DesignCapacity gives 84.6%. Apple's own
# figure is the one the user sees in System Settings, so it is the one to show.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

POPUP="power.popup"

# Toggle first so the popup feels instantaneous; the data lands a moment later.
sketchybar --set power popup.drawing=toggle

BATT=$(ioreg -rn AppleSmartBattery 2>/dev/null)
[ -z "$BATT" ] && exit 0

field() {
  echo "$BATT" | sed -n "s/.*\"$1\" = \([0-9-]*\).*/\1/p" | head -1
}

PERCENT=$(field CurrentCapacity)
CYCLES=$(field CycleCount)
TEMP_RAW=$(field Temperature)
AMPERAGE=$(field Amperage)
VOLTAGE=$(field Voltage)
DESIGN=$(field DesignCapacity)
NOMINAL=$(field NominalChargeCapacity)
# BSD sed has no \| alternation in basic regex, so match the word instead:
# 's/.*"IsCharging" = \(Yes\|No\).*/\1/p' silently yields nothing here.
CHARGING=$(echo "$BATT" | sed -n 's/.*"IsCharging" = \([A-Za-z]*\).*/\1/p' | head -1)
PLUGGED=$(echo "$BATT" | sed -n 's/.*"ExternalConnected" = \([A-Za-z]*\).*/\1/p' | head -1)

# Adapter wattage lives in AppleRawAdapterDetails; scope the match to that
# block, because other "Watts" keys elsewhere in the tree report port power.
ADAPTER_W=$(echo "$BATT" | grep -o 'AppleRawAdapterDetails[^)]*' \
            | grep -oE '"Watts"=[0-9]+' | head -1 | cut -d= -f2)

# --- Derived ---------------------------------------------------------------

TEMP_C=$(echo "scale=1; $TEMP_RAW / 100" | bc 2>/dev/null)

if [ -n "$AMPERAGE" ]; then
  AMPERAGE=$(echo "if ($AMPERAGE > 9223372036854775807) $AMPERAGE - 18446744073709551616 else $AMPERAGE" | bc)
  WATTS=$(echo "scale=1; a = ($AMPERAGE * $VOLTAGE) / 1000000; if (a < 0) -a else a" | bc)
else
  WATTS=0
fi
WATTS_INT=$(printf '%.0f' "$WATTS")

# Apple's own health figure.
HEALTH=$(system_profiler SPPowerDataType 2>/dev/null \
         | sed -n 's/.*Maximum Capacity: *\([0-9]*\).*/\1/p' | head -1)
[ -z "$HEALTH" ] && [ -n "$NOMINAL" ] && [ -n "$DESIGN" ] \
  && HEALTH=$(echo "scale=0; ($NOMINAL * 100) / $DESIGN" | bc)

# Status line, and the flow line that explains it.
if [ "$CHARGING" = "Yes" ]; then
  STATUS="Charging"
  STATUS_COLOR=$AYU_STRING
  FLOW="+${WATTS}W"
elif [ "$PLUGGED" = "Yes" ]; then
  STATUS="On AC"
  STATUS_COLOR=$AYU_UI
  if [ "$WATTS_INT" -ge 1 ]; then FLOW="-${WATTS}W"; else FLOW="idle"; fi
else
  STATUS="On battery"
  STATUS_COLOR=$AYU_ACCENT
  FLOW="-${WATTS}W"
fi

# Time remaining, when the gauge has settled on an estimate. 65535 is IOKit's
# "still calculating" sentinel and must not be shown as a duration.
TIME_RAW=$(field TimeRemaining)
if [ -n "$TIME_RAW" ] && [ "$TIME_RAW" -gt 0 ] && [ "$TIME_RAW" -lt 65535 ]; then
  TIME_LABEL="$((TIME_RAW / 60))h $((TIME_RAW % 60))m"
else
  TIME_LABEL="--"
fi

# --- Render ----------------------------------------------------------------

sketchybar --set ${POPUP}.status  label="$STATUS" label.color="$STATUS_COLOR" \
           --set ${POPUP}.charge  label="${PERCENT}%" \
           --set ${POPUP}.flow    label="$FLOW" \
           --set ${POPUP}.time    label="$TIME_LABEL" \
           --set ${POPUP}.health  label="${HEALTH}%" \
           --set ${POPUP}.cycles  label="$CYCLES" \
           --set ${POPUP}.temp    label="${TEMP_C}°C"

if [ -n "$ADAPTER_W" ]; then
  sketchybar --set ${POPUP}.adapter drawing=on label="${ADAPTER_W}W"
else
  sketchybar --set ${POPUP}.adapter drawing=off
fi
