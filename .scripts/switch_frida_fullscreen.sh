#!/bin/bash

# Get the name of the currently active application
active_app=$(yabai -m query --windows --window | jq -r '.app')

# Check if an active application was found
if [ -n "$active_app" ]; then
  echo "Injecting into: $active_app"
  frida -q -l ~/Documents/OverNotch.js -e "toggleFullScreen()" "$active_app"
else
  echo "No active application found."
  exit 1
fi
