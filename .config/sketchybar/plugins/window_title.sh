#!/usr/bin/env bash
#
# Focused window title.
#
# The app icon says *what* is focused; this says *which thing* -- the Slack
# channel, the browser page, the tmux session. That is usually the part worth
# knowing, and it is the one piece of context the rest of the bar cannot give.
#
# Hidden when the title is empty or merely repeats the app name (Hermes reports
# "Hermes", Chrome sometimes reports nothing), so it never shows a redundant
# second copy of what front_app already displays.
#
# Driven by front_app_switched and window_change -- no polling. yabai's query
# costs ~7ms.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

# The focused window on the currently focused space. Scoped to --space so a
# focused window on another display does not override what is in front here.
FOCUSED=$(yabai -m query --windows --space 2>/dev/null \
  | jq -r '.[] | select(."has-focus") | "\(.app)\t\(.title)"' 2>/dev/null | head -1)

APP="${FOCUSED%%$'\t'*}"
TITLE="${FOCUSED#*$'\t'}"

# Nothing focused, no title, or a title that just echoes the app name: the
# front_app item already covers that case.
#
# The label is cleared as well as hidden. drawing=off alone leaves the previous
# value cached, and the next genuine title would briefly show the old one --
# worse, a query of the item reports a title that is no longer on screen, which
# looks exactly like a stale-update bug.
if [ -z "$TITLE" ] || [ "$TITLE" = "$APP" ] || [ -z "$FOCUSED" ]; then
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
fi

# Strip the trailing app-name suffix many apps append, so
# "devteam (Channel) - zapfloor - Slack" reads as the part that varies rather
# than ending in a word the icon already shows.
TITLE="${TITLE% - $APP}"
TITLE="${TITLE% — $APP}"
TITLE="${TITLE% – $APP}"

# Browsers put the page title first and the app last; after the strip above a
# long tail can remain. Truncate on a character budget rather than a pixel one,
# because the bar has no layout feedback to measure against.
MAX=45
if [ "${#TITLE}" -gt "$MAX" ]; then
  TITLE="$(printf '%.*s' "$MAX" "$TITLE")…"
fi

sketchybar --set "$NAME" drawing=on label="$TITLE"
