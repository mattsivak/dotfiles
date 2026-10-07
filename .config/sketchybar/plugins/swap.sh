#!/bin/sh
#
# Swap usage.
#
# Shows how much has been pushed out of RAM onto disk. This is the number that
# explains a machine feeling slow while the memory widget still looks healthy:
# RAM can read 60% while gigabytes sit swapped out.
#
# The item hides itself entirely when swap is empty, so on a machine that never
# swaps this costs a slot in the bar and nothing visually.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

# vm.swapusage reports like: total = 6144.00M  used = 4517.38M  free = 1626.62M
# Values can carry an M or G suffix, so normalise to MB before comparing.
SWAP=$(sysctl -n vm.swapusage 2>/dev/null)

USED_RAW=$(echo "$SWAP" | sed -n 's/.*used = \([0-9.]*\)\([MG]\).*/\1 \2/p')
USED_NUM=$(echo "$USED_RAW" | awk '{print $1}')
USED_UNIT=$(echo "$USED_RAW" | awk '{print $2}')

[ -z "$USED_NUM" ] && exit 0

if [ "$USED_UNIT" = "G" ]; then
  USED_MB=$(echo "$USED_NUM * 1024" | bc)
else
  USED_MB=$USED_NUM
fi

USED_MB_INT=$(printf '%.0f' "$USED_MB")

# Nothing swapped: hide the item rather than showing a zero.
if [ "$USED_MB_INT" -lt 1 ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Label in whichever unit reads better. printf rather than bare bc: bc drops
# the leading zero below 1, which would render a value as ".8GB".
if [ "$USED_MB_INT" -ge 1024 ]; then
  LABEL="$(printf '%.1f' "$(echo "scale=3; $USED_MB / 1024" | bc)")GB"
else
  LABEL="${USED_MB_INT}MB"
fi

# Any swap at all is worth noticing; a lot of it is a real problem.
if [ "$USED_MB_INT" -ge 8192 ]; then
  COLOR=$AYU_ERROR
elif [ "$USED_MB_INT" -ge 4096 ]; then
  COLOR=$AYU_WARNING
elif [ "$USED_MB_INT" -ge 1024 ]; then
  COLOR=$AYU_ACCENT
else
  COLOR=$AYU_UI
fi

sketchybar --set "$NAME" drawing=on icon="󰓡" icon.color="$COLOR" label="$LABEL"
