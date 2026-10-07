#!/bin/sh
#
# Notch / display geometry detection.
#
# Sourced by sketchybarrc to answer two questions:
#
#   NOTCH_DISPLAY  which sketchybar display index is the built-in screen,
#                  or empty when the lid is closed / no internal display
#   NOTCH_WIDTH    the real width of the notch in points
#
# Why this exists rather than hardcoding the display UUID: the built-in
# display's yabai/sketchybar index is not stable. It depends on how many
# externals are attached and in what order macOS enumerated them, so a
# number baked into the config is wrong the first time a monitor is
# unplugged. Both values are derived from the system every time the bar
# loads.
#
# Sketchybar numbers its displays in SLSCopyManagedDisplays order, which is
# the same order yabai reports as .index, so yabai's index is usable
# directly. The built-in panel is matched via system_profiler's
# spdisplays_connection_type == spdisplays_internal, and joined to yabai by
# CGDirectDisplayID.

# --- Which display is the built-in one? -------------------------------------

NOTCH_DISPLAY=""

_builtin_id=$(system_profiler SPDisplaysDataType -json 2>/dev/null \
  | jq -r '.SPDisplaysDataType[].spdisplays_ndrvs[]?
           | select(.spdisplays_connection_type == "spdisplays_internal")
           | ._spdisplays_displayID' 2>/dev/null)

if [ -n "$_builtin_id" ]; then
  NOTCH_DISPLAY=$(yabai -m query --displays 2>/dev/null \
    | jq -r --arg b "$_builtin_id" \
        '.[] | select(.id == ($b | tonumber)) | .index' 2>/dev/null)
fi

# --- How wide is the notch? -------------------------------------------------
#
# AppKit exposes the two lit areas flanking the notch as auxiliaryTopLeftArea
# and auxiliaryTopRightArea. The notch is whatever is left over:
#
#     notch = screen width - leftArea - rightArea
#
# This is the true width for the specific machine, where sketchybar's default
# of 200 is a generic guess. A screen with no notch returns nil for both
# areas, and the helper prints nothing.
#
# `swift <file>` compiles on each run (~0.4s warm). That is paid once at bar
# load, not per update tick.

NOTCH_WIDTH=$(swift "$CONFIG_DIR/notch_width.swift" 2>/dev/null)

# Fall back to sketchybar's own default if detection fails for any reason:
# a missing swift toolchain, an OS change to the AppKit API, a closed lid.
case "$NOTCH_WIDTH" in
  ''|*[!0-9]*) NOTCH_WIDTH=200 ;;
esac

export NOTCH_DISPLAY NOTCH_WIDTH
