#!/bin/bash

yabai -m rule --add app="zenity" manage=off

DISPLAY=$(yabai -m query --displays --display | jq -r '.index')
# Define the layout options
LAYOUT=$(zenity --list --title="Select Yabai Layout" --column="Layouts" bsp stack float)

# Check if the user selected a layout and apply it to the current display
if [ "$LAYOUT" ]; then
  SPACES=$(yabai -m query --spaces --display "$DISPLAY" | jq -r '.[].index')

  for SPACE in $SPACES; do
    yabai -m config --space "$SPACE" layout "$LAYOUT"
  done
else
  echo "No layout selected."
fi

yabai -m rule --add app="Zenity" manage=on
