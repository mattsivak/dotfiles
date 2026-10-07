#!/bin/sh
#
# GPU utilization.
#
# Read from IOAccelerator's PerformanceStatistics, which is open to any user --
# powermetrics would give wattage too, but needs root.
#
# "Device Utilization %" is the figure Activity Monitor's GPU History graph
# shows. Tiler and Renderer utilization are also there; device utilization is
# the aggregate and the one worth a slot in the bar.
#
# Hidden while idle: a GPU at 0% on a laptop doing text work is the normal
# case, and a permanent "GPU 0%" is noise.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

# -d 1 keeps the traversal shallow; the whole call is ~17ms.
PCT=$(ioreg -rc IOAccelerator -d 1 -w 0 2>/dev/null \
      | grep -o '"Device Utilization %"=[0-9]*' \
      | head -1 | cut -d= -f2)

[ -z "$PCT" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

# Below 5% is idle desktop compositing, not work worth reporting.
if [ "$PCT" -lt 5 ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [ "$PCT" -ge 90 ]; then
  COLOR=$AYU_ERROR
elif [ "$PCT" -ge 70 ]; then
  COLOR=$AYU_WARNING
elif [ "$PCT" -ge 40 ]; then
  COLOR=$AYU_ACCENT
else
  COLOR=$AYU_CONSTANT
fi

sketchybar --set "$NAME" drawing=on icon="󰢮" icon.color="$COLOR" label="${PCT}%"
