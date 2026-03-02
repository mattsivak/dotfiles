#!/bin/bash

# Query open windows and extract the application names, window titles, space, and window IDs
echo "Querying open windows..."
windows=$(yabai -m query --windows)

# Debug: Check if any windows are returned
if [ -z "$windows" ]; then
  echo "No windows found!"
  exit 1
fi

# Format the output for choose, showing app name, title, space, and window ID
window_list=$(echo "$windows" | jq -r '.[] | "\(.app) - \(.title) [Space: \(.space), Window ID: \(.id)]"' | sort -u)

# Debug: Print the list of open windows for selection
echo "List of open windows:"
echo "$window_list"

# Use choose to allow the user to select a window
selected_window=$(echo "$window_list" | choose)

# Debug: Check if a window was selected
if [ -z "$selected_window" ]; then
  echo "No window selected!"
  exit 1
fi

# Debug: Print the selected window
echo "Selected Window: $selected_window"

# Get the space and window ID from the selected window
chosen_window=$(echo "$windows" | jq -r --arg SELECTED "$selected_window" \
  '.[] | select(.app + " - " + .title + " [Space: " + (.space|tostring) + ", Window ID: " + (.id|tostring) + "]" == $SELECTED) | "\(.space) \(.id)"')

# Debug: Print the chosen window's space and window ID
echo "Chosen Window Details: $chosen_window"

# Ensure the chosen window has space and window ID
if [ -z "$chosen_window" ]; then
  echo "Error: No valid window found for selection!"
  exit 1
fi

chosen_space=$(echo "$chosen_window" | awk '{print $1}')
chosen_window_id=$(echo "$chosen_window" | awk '{print $2}')

# Debug: Print the extracted space and window ID
echo "Chosen Space: $chosen_space"
echo "Chosen Window ID: $chosen_window_id"

# Ensure space and window ID are not empty
if [ -z "$chosen_space" ] || [ -z "$chosen_window_id" ]; then
  echo "Error: Space or Window ID is empty!"
  exit 1
fi

# Switch to the space where the app's window is located
echo "Switching to space $chosen_space..."
yabai -m space --focus "$chosen_space"

# Focus the app's window
echo "Focusing on window ID $chosen_window_id..."
yabai -m window --focus "$chosen_window_id"
