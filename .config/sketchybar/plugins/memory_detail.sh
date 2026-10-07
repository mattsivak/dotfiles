#!/bin/sh
#
# Fills and toggles the memory popup.
#
# The headline number in the bar says how full RAM is. This answers the more
# useful question: how much data is the machine actually holding, counting the
# parts that no longer fit in RAM?
#
# macOS compresses cold pages rather than swapping them immediately, so a
# 64GB machine routinely holds far more than 64GB of data. Right now the
# compressor keeps ~39GB of data inside ~16GB of RAM (2.4x), with another
# 4.4GB pushed out to disk. That total -- and the compression ratio behind it
# -- is invisible in every "used/total" reading, including Activity Monitor's.
#
# Click-only, so vm_stat and sysctl are both affordable (3ms each).

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

POPUP="memory.popup"

sketchybar --set memory popup.drawing=toggle

PAGE=$(pagesize)
VM=$(vm_stat)
TOTAL_B=$(sysctl -n hw.memsize)
GB=1073741824

pages() {
  echo "$VM" | sed -n "s/.*$1: *\([0-9]*\)\./\1/p" | head -1
}

gb() {
  # printf, not bc alone: bc drops the leading zero on values below 1, so a
  # free-memory reading of 0.1GB would render as ".1GB".
  printf '%.1f' "$(echo "scale=3; $1 / $GB" | bc)"
}

ACTIVE=$(pages "Pages active")
INACTIVE=$(pages "Pages inactive")
WIRED=$(pages "Pages wired down")
FREE=$(pages "Pages free")
PURGEABLE=$(pages "Pages purgeable")
OCCUPIED=$(pages "Pages occupied by compressor")
STORED=$(pages "Pages stored in compressor")

ACTIVE_GB=$(gb $((ACTIVE * PAGE)))
INACTIVE_GB=$(gb $((INACTIVE * PAGE)))
WIRED_GB=$(gb $((WIRED * PAGE)))
FREE_GB=$(gb $((FREE * PAGE)))
OCCUPIED_GB=$(gb $((OCCUPIED * PAGE)))
STORED_GB=$(gb $((STORED * PAGE)))

# RAM actually occupied, the way Activity Monitor counts it: everything not
# immediately available. Purgeable pages can be dropped on demand, so they do
# not count as used. The bar shows the footprint instead, so this lives here.
RAM_USED_GB=$(gb $((TOTAL_B - (FREE + PURGEABLE) * PAGE)))

# Swap, normalised to GB from vm.swapusage's M/G suffix.
SWAP_RAW=$(sysctl -n vm.swapusage | sed -n 's/.*used = \([0-9.]*\)\([MG]\).*/\1 \2/p')
SWAP_NUM=$(echo "$SWAP_RAW" | awk '{print $1}')
SWAP_UNIT=$(echo "$SWAP_RAW" | awk '{print $2}')
if [ "$SWAP_UNIT" = "M" ]; then
  SWAP_GB=$(printf '%.1f' "$(echo "scale=3; $SWAP_NUM / 1024" | bc)")
else
  SWAP_GB=$SWAP_NUM
fi

# How well the compressor is doing. Guard against a cold boot where nothing
# has been compressed yet and the division would fail.
if [ "$OCCUPIED" -gt 0 ]; then
  RATIO=$(echo "scale=1; $STORED / $OCCUPIED" | bc)
  COMPRESSED_LABEL="${STORED_GB}GB in ${OCCUPIED_GB}GB (${RATIO}x)"
else
  COMPRESSED_LABEL="none"
fi

# The answer to "how much stuff is there, wherever it lives": everything an
# application believes it holds -- resident, compressed (at full size) and
# swapped out. This is the figure shown in the bar; the rows below break it
# down. Kept arithmetically identical to memory.sh so the two never disagree.
FOOTPRINT=$(printf '%.1f' "$(echo "scale=3; (($ACTIVE + $WIRED + $STORED) * $PAGE) / $GB + $SWAP_GB" | bc)")
TOTAL_GB=$(echo "scale=0; $TOTAL_B / $GB" | bc)

# Flag it when the machine is holding more than it physically has.
OVER=$(echo "$FOOTPRINT > $TOTAL_GB" | bc)
if [ "$OVER" -eq 1 ]; then
  FOOTPRINT_COLOR=$AYU_WARNING
else
  FOOTPRINT_COLOR=$AYU_FG
fi

PRESSURE=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)
case "$PRESSURE" in
  4) PRESSURE_LABEL="Critical"; PRESSURE_COLOR=$AYU_ERROR ;;
  2) PRESSURE_LABEL="Warning";  PRESSURE_COLOR=$AYU_WARNING ;;
  *) PRESSURE_LABEL="Normal";   PRESSURE_COLOR=$AYU_STRING ;;
esac

sketchybar --set ${POPUP}.pressure   label="$PRESSURE_LABEL" label.color="$PRESSURE_COLOR" \
           --set ${POPUP}.footprint  label="${FOOTPRINT}GB / ${TOTAL_GB}GB" label.color="$FOOTPRINT_COLOR" \
           --set ${POPUP}.ram        label="${RAM_USED_GB}GB" \
           --set ${POPUP}.app        label="${ACTIVE_GB}GB" \
           --set ${POPUP}.wired      label="${WIRED_GB}GB" \
           --set ${POPUP}.inactive   label="${INACTIVE_GB}GB" \
           --set ${POPUP}.compressed label="$COMPRESSED_LABEL" \
           --set ${POPUP}.swap       label="${SWAP_GB}GB" \
           --set ${POPUP}.free       label="${FREE_GB}GB"
