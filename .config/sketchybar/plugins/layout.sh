#!/bin/sh
#
# yabai layout mode for the focused space.
#
# In a tiling setup the layout is modal: a new window tiles in bsp, stacks in
# stack, and does neither in float. Getting that wrong is a small daily
# annoyance, and the mode is otherwise invisible -- you find out by opening a
# window and seeing what happens.
#
# Shown only when the mode is NOT bsp. bsp is the configured default here
# (.yabairc line 5), so flagging it permanently would be noise; what matters is
# noticing when the space is in one of the other two.
#
# Event-driven via space_changed and window_change; yabai's query is ~7ms.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

LAYOUT=$(yabai -m query --spaces --space 2>/dev/null | jq -r '.type' 2>/dev/null)
[ -z "$LAYOUT" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

case "$LAYOUT" in
  bsp)
    # The default. Nothing to say.
    sketchybar --set "$NAME" drawing=off
    exit 0
    ;;
  stack)
    ICON="󰓩"
    COLOR=$AYU_TAG
    ;;
  float)
    ICON="󰕴"
    COLOR=$AYU_KEYWORD
    ;;
  *)
    ICON="󰕮"
    COLOR=$AYU_UI
    ;;
esac

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COLOR" \
                         label="$LAYOUT"
