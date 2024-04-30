#!/usr/bin/env sh

# Get Wi-Fi information using wdutil
WIFI_INFO=$(sudo wdutil info)

echo $WIFI_INFO

# Parse the output to extract SSID
SSID=$(echo "$WIFI_INFO" | grep 'SSID                 :' | cut -d':' -f2- | tr -d '[:space:]')

# Check if connected
if [ -z "$SSID" ]; then
	sketchybar --set $NAME label="Disconnected" icon=􀙈
else
	sketchybar --set $NAME label="$SSID" icon=􀙇
fi
