#!/bin/sh
#
# Battery power flow, in watts.
#
# Package power (CPU/GPU wattage) would need `powermetrics`, which refuses to
# run without root -- so this measures the battery terminals instead, which any
# user can read. On mains with a full battery the flow is ~0W and the item
# hides itself; the interesting cases are discharging and charging.
#
# watts = amperage * voltage. IOKit reports amperage as a signed value inside
# an unsigned 64-bit field, so negative current (discharging) arrives as a huge
# number near 2^64 and has to be wrapped back to its signed meaning.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

BATT=$(ioreg -rn AppleSmartBattery 2>/dev/null)
[ -z "$BATT" ] && exit 0

AMPERAGE=$(echo "$BATT" | sed -n 's/.*"Amperage" = \([0-9-]*\).*/\1/p' | head -1)
VOLTAGE=$(echo "$BATT" | sed -n 's/.*"Voltage" = \([0-9]*\).*/\1/p' | head -1)

[ -z "$AMPERAGE" ] || [ -z "$VOLTAGE" ] && exit 0

# Wrap the unsigned representation back to signed.
AMPERAGE=$(echo "if ($AMPERAGE > 9223372036854775807) $AMPERAGE - 18446744073709551616 else $AMPERAGE" | bc)

# mA * mV / 1e6 = W. abs() for display; the sign only picks the glyph.
WATTS=$(echo "scale=1; a = ($AMPERAGE * $VOLTAGE) / 1000000; if (a < 0) -a else a" | bc)
WHOLE=$(printf '%.0f' "$WATTS")

# Idle on mains: nothing worth a slot in the bar.
if [ "$WHOLE" -lt 1 ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [ "$AMPERAGE" -lt 0 ]; then
  # Discharging. Higher draw shortens the remaining runtime, so colour it.
  ICON="󱐋"
  if [ "$WHOLE" -ge 40 ]; then
    COLOR=$AYU_ERROR
  elif [ "$WHOLE" -ge 20 ]; then
    COLOR=$AYU_WARNING
  else
    COLOR=$AYU_STRING
  fi
else
  # Charging: power going in is good news regardless of magnitude.
  ICON="󰢝"
  COLOR=$AYU_STRING
fi

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COLOR" label="${WATTS}W"
