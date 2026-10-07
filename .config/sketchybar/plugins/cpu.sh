#!/bin/sh
#
# CPU utilization.
#
# The percentage comes from cpu_usage, a small compiled helper that reads the
# kernel's tick counters -- see cpu_usage.swift for why load average cannot be
# used here (short version: it counts threads waiting, not CPU busy, so it goes
# past 100% while the CPU is idle).
#
# The binary is built on first run and rebuilt whenever the source is newer,
# so a fresh clone of the dotfiles needs no manual build step.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

SRC="$CONFIG_DIR/cpu_usage.swift"
BIN="$CONFIG_DIR/.cache/cpu_usage"

# Build on first run, or when the source has changed. swiftc is not on the
# minimal PATH sketchybar gives plugins, hence the absolute path.
if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
  mkdir -p "$CONFIG_DIR/.cache"
  /usr/bin/swiftc -O -o "$BIN" "$SRC" 2>/dev/null || exit 0
fi

PCT=$("$BIN" 2>/dev/null)

# Fall back silently rather than showing a wrong number.
case "$PCT" in
  ''|*[!0-9]*) exit 0 ;;
esac

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
