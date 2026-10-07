#!/usr/bin/env bash
#
# Focused window title, truncated to the space actually available.
#
# The app icon says *what* is focused; this says *which thing* -- the Slack
# channel, the browser page, the tmux session. That is usually the part worth
# knowing, and the one piece of context the rest of the bar cannot give.
#
# Hidden when the title is empty or merely repeats the app name (Hermes reports
# "Hermes", Chrome sometimes reports nothing), so it never shows a redundant
# second copy of what front_app already displays.
#
# --- Why the truncation is computed rather than a constant -------------------
#
# A fixed character budget is wrong on at least one display. Measured here:
#
#   built-in (1728 wide, split pill)   468 pt free  ->  56 chars
#   external (2560 wide, full pill)   1604 pt free  -> 193 chars
#
# A constant tuned for the laptop wastes most of the external's width; one
# tuned for the external overflows the laptop into the notch. So the budget is
# derived from the live layout: where this item starts, and where the nearest
# thing to its right begins.
#
# Hack Nerd Font is monospaced, so pt-per-character is exact. Measured by
# rendering known-length strings and reading back the item width:
#
#   10 chars -> 96pt, 20 -> 174, 40 -> 331, 60 -> 487
#   => 7.82 pt/char plus 17.8 pt of padding (max error 0.4pt over that range)
#
# Driven by front_app_switched, window_change, space_change and title_change --
# no polling. The whole script costs ~16ms.

[ -n "$CONFIG_DIR" ] && . "$CONFIG_DIR/colors.sh"

# Font metrics for Hack Nerd Font Italic 13.0, measured empirically by
# rendering known-length strings and reading back the item width:
#
#   20 chars -> 175pt, 100 -> 801pt, 200 -> 1584pt
#   => 7.828 pt/char plus 18.4pt of padding (max error 0.22pt across that range)
#
# Hack is monospaced, so this is linear and exact. Keep PT_PER_CHAR scaled by
# 100 to stay in integer arithmetic -- there is no floating point in POSIX sh.
PT_PER_CHAR=783   # 7.83 pt/char, x100
PADDING_PT=19

# Items do not butt up against each other: sketchybar leaves a gap between them
# (measured 10pt here). The budget is derived from front_app's right edge, so
# that gap sits inside the measured span and must be given back, otherwise the
# title is allowed to run past the wall -- observed as a 5pt overflow into the
# cpu widget before this was accounted for.
ITEM_GAP_PT=10

# Never shrink below this: a title cut to a handful of characters says nothing,
# and at that point hiding it entirely would be more honest. In practice this
# only bites if the bar is crowded far beyond its current contents.
MIN_CHARS=12

# Fallback when the geometry cannot be read (query raced a reload, front_app not
# yet drawn). Matches the built-in display's measured budget, the tighter of the
# two, so a failed measurement truncates rather than overflows.
FALLBACK_CHARS=56

# --- Which window? ----------------------------------------------------------

FOCUSED=$(yabai -m query --windows --space 2>/dev/null \
  | jq -r '.[] | select(."has-focus") | "\(.app)\t\(.title)"' 2>/dev/null | head -1)

APP="${FOCUSED%%$'\t'*}"
TITLE="${FOCUSED#*$'\t'}"

# Nothing focused, no title, or a title that just echoes the app name: the
# front_app item already covers that case.
#
# The label is cleared as well as hidden. drawing=off alone leaves the previous
# value cached, and a query then reports a title that is no longer on screen,
# which looks exactly like a stale-update bug.
if [ -z "$TITLE" ] || [ "$TITLE" = "$APP" ] || [ -z "$FOCUSED" ]; then
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
fi

# Strip the trailing app-name suffix most apps append, so
# "devteam (Channel) - zapfloor - Slack" reads as the part that varies rather
# than ending in a word the icon already shows.
TITLE="${TITLE% - $APP}"
TITLE="${TITLE% — $APP}"
TITLE="${TITLE% – $APP}"

# --- How much room is there? ------------------------------------------------
#
# The wall on this item's right depends on the display:
#
#   built-in  notch_left -- the left pill stops at the notch
#   external  cpu        -- the leftmost right-side widget in the full pill
#
# notch_left is a `q`-positioned anchor, which sketchybar places at the screen
# centre on a display with no notch. On an external it therefore sits in the
# middle of the full pill and is NOT a wall -- taking the nearest item to the
# right would wrongly stop the title there. So the notch anchor only counts on
# the built-in display.
#
# Which display that is comes from notch.sh (NOTCH_DISPLAY), resolved live as
# the display at origin (0,0) rather than hardcoded -- indices shift when
# monitors are plugged, unplugged or rearranged.
#
# Both walls are fetched in a single batched call (sketchybar accepts repeated
# --query and concatenates the JSON, ~6ms). Scanning every item instead would
# mean ~20 round trips on an event that fires on every browser tab switch,
# which is what the separate title_change event exists to avoid.
#
# The item must be drawing before it has a rect to measure from, and it is
# hidden whenever the previous title was empty. Showing it first would flash
# the stale label, so measurement happens against front_app instead -- it sits
# immediately to the left, is always drawn, and its right edge is where this
# item begins.

# NOTCH_DISPLAY is the sketchybar display index of the built-in screen, or
# empty when there is none (lid closed, desktop Mac).
#
# It is read from the cache sketchybarrc writes at startup, NOT by sourcing
# notch.sh: that shells out to swift and system_profiler and costs ~1.5s, which
# on an event firing per browser tab switch would be 80x the rest of this
# script put together. The cache is rewritten on every reload, and reloads are
# exactly when the display layout can have changed.
NOTCH_DISPLAY=""
[ -n "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/.notch_cache" ] && \
  read -r NOTCH_DISPLAY < "$CONFIG_DIR/.notch_cache"
NOTCH_KEY="display-${NOTCH_DISPLAY:-0}"

GEOM=$(sketchybar --query front_app --query notch_left --query cpu 2>/dev/null)

AVAILABLE=$(printf '%s' "$GEOM" | jq -rs --arg notchkey "$NOTCH_KEY" '
  # Where this item starts: the right edge of front_app, on whichever display
  # is currently drawing it. -9999 is sketchybar s "not on this display".
  (map(select(.name == "front_app")) | .[0].bounding_rects
   | to_entries | map(select(.value.origin[0] > -9000)) | .[0]) as $anchor
  | if $anchor == null then empty
    else
      $anchor.key as $disp
      | ($anchor.value.origin[0] + $anchor.value.size[0]) as $x
      # The notch anchor is only a wall on the built-in display. Elsewhere it
      # collapses to the screen centre and means nothing.
      | (if $disp == $notchkey then ["notch_left", "cpu"] else ["cpu"] end) as $names
      | ( map(select(.name as $n | $names | index($n))
              | .bounding_rects[$disp]
              | select(. != null)
              | .origin[0])
          | map(select(. > $x)) ) as $walls
      | if ($walls | length) == 0 then empty else (($walls | min) - $x) end
    end
' 2>/dev/null)

if [ -n "$AVAILABLE" ] && [ "${AVAILABLE%.*}" -gt 0 ] 2>/dev/null; then
  MAX=$(( ( ${AVAILABLE%.*} - ITEM_GAP_PT - PADDING_PT ) * 100 / PT_PER_CHAR ))
else
  MAX=$FALLBACK_CHARS
fi

[ "$MAX" -lt "$MIN_CHARS" ] && MAX=$MIN_CHARS

# --- Render -----------------------------------------------------------------

if [ "${#TITLE}" -gt "$MAX" ]; then
  TITLE="$(printf '%.*s' "$MAX" "$TITLE")…"
fi

sketchybar --set "$NAME" drawing=on label="$TITLE"
