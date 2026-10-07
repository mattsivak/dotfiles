#!/usr/bin/env bash
#
# Space indicator: the space number, plus a glyph for each app on that space.
#
# A bare number says nothing about what is on a space -- you have to visit it
# to find out. Showing the apps turns the indicator into a map: space 2 holding
# a browser and a terminal is recognisable at a glance, and an empty space is
# visibly empty.
#
# Icons come from sketchybar-app-font via icon_map.sh (a generated bash case
# statement over ~900 apps). bash rather than sh because that file uses
# bash-only syntax and silently fails to define its function under dash.
#
# Called two ways:
#   - by sketchybar as a space component's script, with $SELECTED set
#   - by the window_change event for every space, to refresh the app list
#
# $NAME is like "space.3"; the trailing number is the yabai space index.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

SID="${NAME##*.}"

# --- Selection highlight ----------------------------------------------------
#
# $SELECTED is only set when sketchybar invokes this as a space component. On a
# window_change refresh it is empty, and the highlight must be left alone --
# otherwise every refresh would unhighlight the focused space.

if [ -n "$SELECTED" ]; then
  if [ "$SELECTED" = "true" ]; then
    sketchybar --set "$NAME" background.drawing=on icon.color="$SPACE_ACTIVE_FG"
  else
    sketchybar --set "$NAME" background.drawing=off icon.color="$SPACE_IDLE_FG"
  fi
fi

# --- App glyphs -------------------------------------------------------------

[ -f "$CONFIG_DIR/icon_map.sh" ] || exit 0
# shellcheck source=/dev/null
source "$CONFIG_DIR/icon_map.sh"

# Local overrides are applied after the generated map, which is replaced on
# every font update.
[ -f "$CONFIG_DIR/icon_map_local.sh" ] && source "$CONFIG_DIR/icon_map_local.sh"

glyph_for() {
  __icon_map "$1"
  if declare -f __icon_map_local >/dev/null 2>&1; then
    __icon_map_local "$1" || true
  fi
}

# Minimised and hidden windows still belong to the space but are not on it in
# any visual sense, so they are excluded -- the same rule the desktop-icon
# script uses. Duplicate app names collapse here: three terminal windows is
# still "there is a terminal here".
APPS=$(yabai -m query --windows --space "$SID" 2>/dev/null \
  | jq -r '[.[] | select(."is-minimized" == false and ."is-hidden" == false) | .app]
           | unique | .[]' 2>/dev/null)

# Deduplicating app names is not enough: distinct apps can share a glyph.
# "Beeper" and "Beeper Desktop" are two different window owners that both map
# to :beeper:, which rendered as two identical icons side by side. The same
# goes for helper processes that ship under a slightly different name. So the
# dedupe happens on the glyph, after mapping, not on the name before it.
GLYPHS=""
SEEN=""
while IFS= read -r app; do
  [ -z "$app" ] && continue
  glyph_for "$app"
  [ -z "$icon_result" ] && continue
  # Substring match is safe because every glyph is colon-delimited, so
  # ":beeper:" cannot match inside ":beeper_beta:" without the colons lining up.
  case "$SEEN" in
    *"$icon_result"*) continue ;;
  esac
  SEEN="${SEEN}${icon_result}"
  GLYPHS="${GLYPHS}${icon_result}"
done <<< "$APPS"

if [ -n "$GLYPHS" ]; then
  sketchybar --set "$NAME" label="$GLYPHS" label.drawing=on \
                           label.font="sketchybar-app-font:Regular:14.0"
else
  # Empty space: the number alone, no trailing gap.
  sketchybar --set "$NAME" label.drawing=off
fi
