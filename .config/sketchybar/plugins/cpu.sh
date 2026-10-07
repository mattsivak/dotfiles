#!/bin/sh
#
# CPU load.
#
# Uses the kernel's load average rather than `top -l 1`, which costs ~590ms per
# call against ~3ms for sysctl. At a 10s refresh that difference is the whole
# cost of the widget.
#
# Load average is not CPU percentage: it counts threads wanting to run, so it
# can exceed the core count under contention. Normalising by core count gives a
# figure where 100% means "every core has exactly one thread's worth of work" --
# which is the honest reading of a saturated machine.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

# { 13.24 11.82 10.73 } -- 1, 5 and 15 minute averages. The 1 minute figure is
# the responsive one.
LOAD=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
NCPU=$(sysctl -n hw.ncpu 2>/dev/null)

[ -z "$LOAD" ] || [ -z "$NCPU" ] && exit 0

PCT=$(echo "scale=0; ($LOAD * 100) / $NCPU" | bc 2>/dev/null)
[ -z "$PCT" ] && exit 0

if [ "$PCT" -ge 90 ]; then
  COLOR=$AYU_ERROR
elif [ "$PCT" -ge 70 ]; then
  COLOR=$AYU_WARNING
elif [ "$PCT" -ge 40 ]; then
  COLOR=$AYU_ACCENT
else
  COLOR=$AYU_ENTITY
fi

sketchybar --set "$NAME" icon="󰻠" icon.color="$COLOR" label="${PCT}%"
