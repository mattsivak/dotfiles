#!/bin/bash

# Get the window ID of the "Zen Browser"
zen_window_id=$(yabai -m query --windows | jq -r '.[] | select(.app == "Zen Browser") | .id')

# Check if Zen Browser window was found
if [ -z "$zen_window_id" ]; then
  # terminal-notifier -title "Zen Browser Focus" -message "Zen Browser window not found."
  exit 1
fi

# Get the corresponding space for the Zen Browser window
zen_space_id=$(yabai -m query --windows --window "$zen_window_id" | jq -r '.space')

# Focus on the space containing the Zen Browser window
yabai -m space --focus "$zen_space_id"

# Focus on the Zen Browser window
yabai -m window --focus "$zen_window_id"

# Send a notification that the window was focused successfully
# terminal-notifier -title "Zen Browser Focus"
