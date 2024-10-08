#!/bin/bash

yabai -m rule --add app="zenity" manage=off

# Define the layout options
LAYOUT=$(zenity --list --title="Select Yabai Layout" --column="Layouts" bsp stack float)

# Check if the user selected a layout and apply it
if [ "$LAYOUT" ]; then
  yabai -m config layout "$LAYOUT"
else
  echo "No layout selected."
fi

yabai -m rule --add app="Zenity" manage=on
