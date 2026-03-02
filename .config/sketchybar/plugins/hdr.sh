#!/bin/sh

# Get HDR status for display with focused window
HDR_STATUS="$(betterdisplaycli get -displayWithFocus -hdr 2>/dev/null)"

if echo "$HDR_STATUS" | grep -qi "on"; then
  ICON="󰌁"
  LABEL="HDR"
else
  ICON="󰌃"
  LABEL="SDR"
fi

sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
