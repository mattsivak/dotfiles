#!/usr/bin/env bash
#
# Front app name plus its icon.
#
# The icon comes from sketchybar-app-font, which maps an application name to a
# glyph in a custom font. icon_map.sh ships with the font release and is a
# generated case statement over ~900 apps, setting $icon_result; unknown apps
# fall through to :default: rather than rendering nothing.
#
# bash rather than sh: icon_map.sh is generated as a bash script and uses
# bash-only syntax, so running it under dash silently fails to define the
# function.
#
# Fires on front_app_switched only -- no polling.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

if [ "$SENDER" != "front_app_switched" ]; then
  exit 0
fi

APP="$INFO"
[ -z "$APP" ] && exit 0

ICON=""
if [ -f "$CONFIG_DIR/icon_map.sh" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/icon_map.sh"
  # Local overrides last: icon_map.sh is regenerated on every font update.
  [ -f "$CONFIG_DIR/icon_map_local.sh" ] && source "$CONFIG_DIR/icon_map_local.sh"
  __icon_map "$APP"
  if declare -f __icon_map_local >/dev/null 2>&1; then
    __icon_map_local "$APP" || true
  fi
  ICON="$icon_result"
fi

if [ -n "$ICON" ]; then
  sketchybar --set "$NAME" icon="$ICON" icon.drawing=on \
                           icon.font="sketchybar-app-font:Regular:16.0" \
                           icon.color="$AYU_ACCENT" \
                           label="$APP"
else
  # Font or map missing: show the name alone rather than an empty box.
  sketchybar --set "$NAME" icon.drawing=off label="$APP"
fi
