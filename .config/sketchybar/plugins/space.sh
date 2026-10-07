#!/bin/sh

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
#
# Colors come from colors.sh, which sketchybarrc sources and exports. Sourcing
# again here keeps the script correct when sketchybar invokes it directly.
[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" background.drawing=on icon.color="$SPACE_ACTIVE_FG"
else
  sketchybar --set "$NAME" background.drawing=off icon.color="$SPACE_IDLE_FG"
fi
