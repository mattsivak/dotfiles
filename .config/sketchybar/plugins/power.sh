#!/bin/sh
#
# Battery and power, in one item.
#
# Replaces seven separate widgets (power_system / power_adapter /
# power_charging / power_cpu / power_gpu / power_ane / power_display) that all
# fed on /usr/local/bin/mac_power_monitor -- a binary that was never installed
# on this machine. They polled for it every 2s, found nothing, set themselves
# to drawing=off, and dragged 133 hidden popup sub-items along for the ride.
#
# Everything here comes from ioreg, which any user can read. Per-component
# wattage (CPU/GPU/ANE) is deliberately absent: that needs powermetrics, which
# refuses to run without root. Better one honest widget than seven blank ones.
#
# Tick cost ~13ms. The popup is filled by power_detail.sh on click, where a
# slower but richer source is affordable.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

BATT=$(ioreg -rn AppleSmartBattery 2>/dev/null)
[ -z "$BATT" ] && exit 0

field() {
  echo "$BATT" | sed -n "s/.*\"$1\" = \([0-9-]*\).*/\1/p" | head -1
}

PERCENT=$(field CurrentCapacity)
AMPERAGE=$(field Amperage)
VOLTAGE=$(field Voltage)
# BSD sed has no \| alternation in basic regex, so match the word instead:
# 's/.*"IsCharging" = \(Yes\|No\).*/\1/p' silently yields nothing here.
CHARGING=$(echo "$BATT" | sed -n 's/.*"IsCharging" = \([A-Za-z]*\).*/\1/p' | head -1)
PLUGGED=$(echo "$BATT" | sed -n 's/.*"ExternalConnected" = \([A-Za-z]*\).*/\1/p' | head -1)

[ -z "$PERCENT" ] && exit 0

# IOKit stores a signed amperage in an unsigned 64-bit field, so a discharging
# battery arrives as a value near 2^64. Wrap it back before using the sign.
if [ -n "$AMPERAGE" ]; then
  AMPERAGE=$(echo "if ($AMPERAGE > 9223372036854775807) $AMPERAGE - 18446744073709551616 else $AMPERAGE" | bc)
  WATTS=$(echo "scale=1; a = ($AMPERAGE * $VOLTAGE) / 1000000; if (a < 0) -a else a" | bc)
else
  WATTS=0
fi

WATTS_INT=$(printf '%.0f' "$WATTS")

# Battery glyph tracks the charge level the way the system one does.
if [ "$CHARGING" = "Yes" ]; then
  ICON="󰂄"
elif [ "$PERCENT" -ge 90 ]; then ICON="󰁹"
elif [ "$PERCENT" -ge 70 ]; then ICON="󰂀"
elif [ "$PERCENT" -ge 50 ]; then ICON="󰁾"
elif [ "$PERCENT" -ge 30 ]; then ICON="󰁼"
elif [ "$PERCENT" -ge 10 ]; then ICON="󰁺"
else ICON="󰂎"
fi

# Colour carries urgency, not decoration: red only when it actually matters,
# and never while plugged in, where a low percentage is not a problem.
if [ "$CHARGING" = "Yes" ]; then
  COLOR=$AYU_STRING
elif [ "$PLUGGED" = "Yes" ]; then
  COLOR=$AYU_UI
elif [ "$PERCENT" -le 10 ]; then
  COLOR=$AYU_ERROR
elif [ "$PERCENT" -le 20 ]; then
  COLOR=$AYU_WARNING
elif [ "$PERCENT" -le 40 ]; then
  COLOR=$AYU_ACCENT
else
  COLOR=$AYU_STRING
fi

# The label earns its width: percentage always, plus the draw when power is
# actually moving. Idle on mains shows just the percentage rather than "0W".
if [ "$WATTS_INT" -ge 1 ]; then
  LABEL="${PERCENT}% ${WATTS}W"
else
  LABEL="${PERCENT}%"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="$LABEL"
