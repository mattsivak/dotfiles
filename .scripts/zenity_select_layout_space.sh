#!/bin/bash

# Temporarily disable managing Zenity windows in yabai
yabai -m rule --add app="zenity" manage=off

# Get the current display and space
DISPLAY=$(yabai -m query --displays --display | jq -r '.index')
CURRENT_SPACE=$(yabai -m query --spaces --space | jq -r '.index')

# Define the layout options
LAYOUT=$(zenity --list --title="Select Yabai Layout" --column="Layouts" bsp stack float)

# Check if the user selected a layout and apply it to the current space only
if [ "$LAYOUT" ]; then
  yabai -m config --space "$CURRENT_SPACE" layout "$LAYOUT"
else
  echo "No layout selected."
fi

# Re-enable managing Zenity windows in yabai
yabai -m rule --add app="Zenity" manage=on
