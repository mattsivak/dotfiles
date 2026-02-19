#!/bin/sh

# Get memory info using vm_stat
PAGE_SIZE=$(pagesize)
VM_STAT=$(vm_stat)

# Parse vm_stat output
PAGES_FREE=$(echo "$VM_STAT" | grep "Pages free" | awk '{print $3}' | tr -d '.')
PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active" | awk '{print $3}' | tr -d '.')
PAGES_INACTIVE=$(echo "$VM_STAT" | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
PAGES_SPECULATIVE=$(echo "$VM_STAT" | grep "Pages speculative" | awk '{print $3}' | tr -d '.')
PAGES_WIRED=$(echo "$VM_STAT" | grep "Pages wired down" | awk '{print $4}' | tr -d '.')
PAGES_COMPRESSED=$(echo "$VM_STAT" | grep "Pages occupied by compressor" | awk '{print $5}' | tr -d '.')

# Calculate used and total memory in bytes
USED_PAGES=$((PAGES_ACTIVE + PAGES_WIRED + PAGES_COMPRESSED))
TOTAL_PAGES=$((PAGES_FREE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED + PAGES_COMPRESSED))

# Convert to GB
USED_GB=$(echo "scale=1; ($USED_PAGES * $PAGE_SIZE) / 1073741824" | bc)
TOTAL_GB=$(echo "scale=0; ($TOTAL_PAGES * $PAGE_SIZE) / 1073741824" | bc)

# Calculate percentage
PERCENTAGE=$(echo "scale=0; ($USED_PAGES * 100) / $TOTAL_PAGES" | bc)

# Choose icon based on usage
if [ "$PERCENTAGE" -ge 90 ]; then
  ICON="󰍛"
elif [ "$PERCENTAGE" -ge 70 ]; then
  ICON="󰍛"
elif [ "$PERCENTAGE" -ge 50 ]; then
  ICON="󰍛"
else
  ICON="󰍛"
fi

sketchybar --set "$NAME" icon="$ICON" label="${USED_GB}/${TOTAL_GB}GB"
