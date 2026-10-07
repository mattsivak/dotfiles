#!/bin/sh
#
# Memory -- total footprint, not RAM fullness.
#
# The bar shows how much data the machine is actually holding, counting the
# parts that no longer fit in RAM: resident pages, the full uncompressed size
# of everything in the compressor, and whatever has been pushed to swap.
#
# That number exceeds installed RAM and is meant to. macOS compresses cold
# pages rather than swapping them, so a 64GB machine routinely holds ~68GB of
# live data at 2.4x compression. "59/64GB" cannot express that -- it saturates
# near full and stops being informative exactly when load gets interesting,
# because macOS deliberately keeps RAM full. The footprint keeps climbing and
# shows the real demand.
#
# Earlier versions of this script were wrong in three ways, all worth keeping
# in mind if it is ever rewritten:
#
#   1. Summing vm_stat page buckets for the total gives 62.8GB on a 64GB
#      machine -- kernel-reserved pages never appear in those buckets.
#      hw.memsize is the real figure.
#   2. Counting the compressor's *compressed* size as "used" (41.3GB) while
#      ignoring inactive pages, when Activity Monitor showed 60GB.
#   3. Colouring by an invented percentage instead of the kernel's pressure
#      level, so it could show red while macOS considered pressure normal.
#
# Colour comes from kern.memorystatus_vm_pressure_level, the same signal behind
# Activity Monitor's pressure graph. Pressure, not fullness, predicts a slow
# machine. The breakdown behind this number is in the click popup.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

PAGE=$(pagesize)
VM=$(vm_stat)
TOTAL_B=$(sysctl -n hw.memsize)
GB=1073741824

pages() {
  echo "$VM" | sed -n "s/.*$1: *\([0-9]*\)\./\1/p" | head -1
}

ACTIVE=$(pages "Pages active")
WIRED=$(pages "Pages wired down")
STORED=$(pages "Pages stored in compressor")

# Swap, normalised to GB from vm.swapusage's M/G suffix.
SWAP_RAW=$(sysctl -n vm.swapusage | sed -n 's/.*used = \([0-9.]*\)\([MG]\).*/\1 \2/p')
SWAP_NUM=$(echo "$SWAP_RAW" | awk '{print $1}')
SWAP_UNIT=$(echo "$SWAP_RAW" | awk '{print $2}')
[ -z "$SWAP_NUM" ] && SWAP_NUM=0
if [ "$SWAP_UNIT" = "M" ]; then
  SWAP_GB=$(echo "scale=2; $SWAP_NUM / 1024" | bc)
else
  SWAP_GB=$SWAP_NUM
fi

# Everything the system is holding: resident (active + wired), plus the full
# uncompressed size of compressed pages, plus swap.
#
# STORED is used rather than "Pages occupied by compressor" on purpose: the
# occupied figure is the compressed footprint already counted inside RAM, while
# stored is the data's real size -- which is the whole point of this number.
#
# Rounded explicitly: bc carries the widest scale of its operands, so the
# swap division above would otherwise leak a second decimal into the label.
FOOTPRINT=$(printf '%.1f' "$(echo "scale=3; (($ACTIVE + $WIRED + $STORED) * $PAGE) / $GB + $SWAP_GB" | bc)")
TOTAL_GB=$(echo "scale=0; $TOTAL_B / $GB" | bc)

# The kernel's own verdict: 1 normal, 2 warning, 4 critical.
PRESSURE=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)

case "$PRESSURE" in
  4) COLOR=$AYU_ERROR ;;
  2) COLOR=$AYU_WARNING ;;
  *)
    # Pressure is normal, but holding more than physical RAM is still worth
    # flagging -- it is the state that precedes pressure rising.
    OVER=$(echo "$FOOTPRINT > $TOTAL_GB" | bc)
    if [ "$OVER" -eq 1 ]; then
      COLOR=$AYU_ACCENT
    else
      COLOR=$AYU_ENTITY
    fi
    ;;
esac

sketchybar --set "$NAME" icon="󰍛" icon.color="$COLOR" \
                         label="${FOOTPRINT}/${TOTAL_GB}GB"
