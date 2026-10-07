#!/bin/sh
#
# Show desktop icons only when the visible space on the main display is empty.
#
# macOS draws desktop icons on the main display only, so that is the one whose
# emptiness decides. Icons stay hidden the rest of the time, which is what
# HideDesktop=1 was already doing permanently -- this just makes it conditional.
#
# Driven by yabai signals (see .yabairc), not a timer: it runs on window and
# space events, costs ~15ms, and does nothing when the state has not changed.
#
# --- Layout independence ---------------------------------------------------
#
# Nothing here is hardcoded to a display index or UUID. Indices shift when a
# monitor is plugged in, unplugged, or rearranged in System Settings, and the
# main display itself can be reassigned at any time.
#
# The main display is identified by its origin being exactly (0,0): macOS
# defines the main display as the coordinate-space origin, so this holds for
# every arrangement, including a single built-in screen with the lid open or a
# clamshell setup driving externals only.
#
# `system_profiler ... spdisplays_main` would also answer this, but costs
# ~990ms against ~10ms for yabai -- far too slow for something firing on every
# window event.
#
# Usage: desktop_icons_auto.sh        evaluate and apply
#        desktop_icons_auto.sh --off  force icons hidden (and stop tracking)

set -eu

STATE_FILE="${TMPDIR:-/tmp}/.desktop_icons_state"

apply() {
  want="$1"   # "show" or "hide"

  # Skip the write when nothing changed. `defaults write` is cheap but not
  # free, and WindowManager redraws on every write even when the value is
  # identical, which produces a visible flicker during rapid window churn.
  if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "$want" ]; then
    exit 0
  fi

  case "$want" in
    show) value=false ;;   # HideDesktop=false -> icons visible
    hide) value=true  ;;
  esac

  defaults write com.apple.WindowManager HideDesktop -bool "$value"
  printf '%s' "$want" > "$STATE_FILE"
}

if [ "${1:-}" = "--off" ]; then
  apply hide
  exit 0
fi

# --- Which display is the main one? ----------------------------------------

DISPLAYS=$(yabai -m query --displays 2>/dev/null) || exit 0
[ -n "$DISPLAYS" ] || exit 0

MAIN_INDEX=$(echo "$DISPLAYS" \
  | jq -r 'map(select(.frame.x == 0 and .frame.y == 0)) | .[0].index // empty' 2>/dev/null)

# No display at the origin should be impossible, but a transient state during
# a hotplug can produce it. Leave the icons as they are rather than guessing.
[ -n "$MAIN_INDEX" ] || exit 0

# --- Is its visible space empty? -------------------------------------------

VISIBLE_SPACE=$(yabai -m query --spaces --display "$MAIN_INDEX" 2>/dev/null \
  | jq -r 'map(select(."is-visible")) | .[0].index // empty' 2>/dev/null)

[ -n "$VISIBLE_SPACE" ] || exit 0

# Count only windows that actually occupy the screen.
#
# Minimised and hidden windows still belong to the space but cover nothing, so
# a space holding only those is empty to the eye. Sticky windows appear on
# every space; counting them would mean the desktop never looks empty anywhere.
COUNT=$(yabai -m query --windows --space "$VISIBLE_SPACE" 2>/dev/null \
  | jq '[.[] | select(."is-minimized" == false
                  and ."is-hidden" == false
                  and ."is-sticky" == false)] | length' 2>/dev/null)

[ -n "$COUNT" ] || exit 0

if [ "$COUNT" -eq 0 ]; then
  apply show
else
  apply hide
fi
