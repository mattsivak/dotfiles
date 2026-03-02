#!/bin/bash

# Use Zenity to select an opacity level from predefined options
opacity=$(zenity --list --title="Select Opacity" --column="Opacity" 50 60 70 80 90 100)

# Check if the user canceled the dialog
if [ -z "$opacity" ]; then
  exit 1
fi

# Convert percentage to decimal (e.g., 90 -> 0.9)
opacity_decimal=$(awk "BEGIN {printf \"%.2f\", $opacity / 100}")

# Apply the opacity setting with yabai
yabai -m config normal_window_opacity $opacity_decimal
