#!/usr/bin/env bash
#$PLUGIN_DIR/stats/scripts/cpu.sh

sketchybar -m --set "$NAME" label="$(top -l 2 | grep -E "^CPU" | tail -1 | awk '{ print $3 + $5"%" }')"
