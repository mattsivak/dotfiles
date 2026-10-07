#!/bin/sh

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

if [ "$PERCENTAGE" = "100" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Icon by charge level; color carries the warning so a low battery reads at a
# glance rather than requiring the number to be parsed.
case "${PERCENTAGE}" in
  9[0-9]) ICON="󰁹"; COLOR=$AYU_STRING
  ;;
  [6-8][0-9]) ICON="󰂀"; COLOR=$AYU_STRING
  ;;
  [3-5][0-9]) ICON="󰁾"; COLOR=$AYU_ACCENT
  ;;
  [1-2][0-9]) ICON="󰁻"; COLOR=$AYU_WARNING
  ;;
  *) ICON="󰁺"; COLOR=$AYU_ERROR
esac

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" \
                         label="${PERCENTAGE}%" drawing=on
