#!/usr/bin/env bash
#
# Focus the bookmarks strip in the minimal Firefox chrome.
#
# Firefox exposes no command to focus the bookmarks toolbar, and F6 -- the
# key every guide names for cycling chrome -- does nothing here: measured with
# real keystrokes through the widget layer, six F6 presses left focus on
# <browser> every time. A keybind would need userChrome.js, which means
# modifying the signed app bundle. This replays the route that does work:
#
#     Cmd+L   focus the address bar
#     Tab     -> Extensions button
#     Tab     -> first bookmark cell
#
# The hop count is stable: Firefox groups the whole extension area into ONE
# <toolbartabstop>, so the route is 2 Tabs whether 0, 1 or 3 extensions are
# pinned (verified at each count). It does NOT depend on how many bookmarks
# are on the strip.
#
# Afterwards: arrows walk the folders, Down/Enter opens one, Esc leaves.

set -euo pipefail

# Guard: only act when Firefox is actually frontmost. skhd already scopes the
# binding by app, but this script may be run by hand, and blind Cmd+L into
# the wrong window would type into whatever is focused.
front=$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)
case "$front" in
  firefox|Firefox) ;;
  *)
    echo "not focusing: frontmost app is '${front:-unknown}', not Firefox" >&2
    exit 1
    ;;
esac

# skhd-zig synthesizes keys natively (-k), so no cliclick and no extra
# Accessibility grant beyond the one skhd already holds.
skhd -k "cmd - l"
sleep 0.12
skhd -k "tab"
sleep 0.08
skhd -k "tab"
