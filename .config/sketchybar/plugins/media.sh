#!/bin/sh
#
# Now playing, for the centre of the notched display.
#
# Driven by sketchybar's built-in media support, which hooks MediaRemote
# notifications directly -- so this runs only when the track actually changes,
# never on a timer. $INFO arrives as JSON from the media_change event.
#
# Hides itself when nothing is playing, so the centre of the bar is empty
# rather than showing a stale track.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

STATE=$(echo "$INFO" | jq -r '.state // empty' 2>/dev/null)

# Only draw while actually playing. Paused media stays hidden: a bar is
# ambient, and a frozen title reads as a bug.
if [ "$STATE" != "playing" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

TITLE=$(echo "$INFO" | jq -r '.title // empty' 2>/dev/null)
ARTIST=$(echo "$INFO" | jq -r '.artist // empty' 2>/dev/null)

[ -z "$TITLE" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

# Keep the centre from pushing into the side pills on a 1728pt screen.
MAX=30
if [ -n "$ARTIST" ]; then
  LABEL="$ARTIST — $TITLE"
else
  LABEL="$TITLE"
fi

if [ "${#LABEL}" -gt "$MAX" ]; then
  LABEL="$(printf '%.*s' "$MAX" "$LABEL")…"
fi

sketchybar --set "$NAME" drawing=on icon="󰎆" icon.color=$AYU_CONSTANT \
                         label="$LABEL"
