#!/usr/bin/env bash
#
# Install the minimal Firefox chrome into a real profile.
#
#   ./install.sh                 # default-release profile, with a backup
#   ./install.sh --profile NAME  # a specific profile directory name
#   ./install.sh --uninstall     # restore the most recent backup
#   ./install.sh --dry-run       # print what would happen
#
# Everything it writes is confined to <profile>/chrome/ and <profile>/user.js.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF_DIR="$HOME/Library/Application Support/Firefox"
PROFILES_DIR="$FF_DIR/Profiles"
STAMP="$(date +%Y%m%d-%H%M%S)"

PROFILE_NAME=""
DRY_RUN=0
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)   PROFILE_NAME="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)   sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" = 1 ]; then say "  would: $*"; else "$@"; fi; }

# --- locate the profile -----------------------------------------------------
if [ -n "$PROFILE_NAME" ]; then
  PROFILE="$PROFILES_DIR/$PROFILE_NAME"
else
  # The [InstallXXXX] section's Default= is the profile Firefox actually opens;
  # the [ProfileN] Default=1 flag is a different, older mechanism and is often
  # stale. Prefer the install section and fall back to a *.default-release glob.
  rel="$(awk -F= '/^\[Install/{ins=1;next} /^\[/{ins=0} ins && /^Default=/{print $2;exit}' \
         "$FF_DIR/profiles.ini" 2>/dev/null || true)"
  if [ -n "$rel" ]; then
    PROFILE="$FF_DIR/$rel"
  else
    PROFILE="$(find "$PROFILES_DIR" -maxdepth 1 -name '*.default-release' | head -1)"
  fi
fi

[ -d "$PROFILE" ] || { echo "profile not found: $PROFILE" >&2; exit 1; }
say "profile: $PROFILE"

# Firefox rewrites prefs.js on exit and would clobber a live edit.
# A dry run writes nothing, so it is safe to inspect while Firefox is open.
if [ "$DRY_RUN" = 0 ] && pgrep -x firefox >/dev/null 2>&1; then
  echo "Firefox is running. Quit it first (it rewrites prefs.js on exit)." >&2
  exit 1
fi

# --- uninstall --------------------------------------------------------------
if [ "$UNINSTALL" = 1 ]; then
  backup="$(find "$PROFILE" -maxdepth 1 -name 'chrome.backup-*' -type d \
            | sort | tail -1)"
  if [ -n "$backup" ]; then
    say "restoring $backup"
    run rm -rf "$PROFILE/chrome"
    run mv "$backup" "$PROFILE/chrome"
  else
    say "no chrome backup found; removing the chrome dir we installed"
    run rm -rf "$PROFILE/chrome"
  fi
  ujs="$(find "$PROFILE" -maxdepth 1 -name 'user.js.backup-*' | sort | tail -1)"
  if [ -n "$ujs" ]; then
    run mv "$ujs" "$PROFILE/user.js"
  else
    run rm -f "$PROFILE/user.js"
  fi
  say
  say "Removed. NOTE: user.js only stops *pinning* prefs — the values it already"
  say "wrote are still in prefs.js. Reset them in about:config if you want the"
  say "stock behaviour back (search 'widget.macos.native-context-menus' etc)."
  exit 0
fi

# --- install ----------------------------------------------------------------
if [ -d "$PROFILE/chrome" ]; then
  say "backing up existing chrome/ -> chrome.backup-$STAMP"
  run cp -R "$PROFILE/chrome" "$PROFILE/chrome.backup-$STAMP"
fi
if [ -f "$PROFILE/user.js" ]; then
  say "backing up existing user.js -> user.js.backup-$STAMP"
  run cp "$PROFILE/user.js" "$PROFILE/user.js.backup-$STAMP"
fi

run mkdir -p "$PROFILE/chrome"
run cp "$SRC/userChrome.css"   "$PROFILE/chrome/userChrome.css"
run cp "$SRC/userContent.css"  "$PROFILE/chrome/userContent.css"
run cp "$SRC/user.js"          "$PROFILE/user.js"

say
say "Installed. Start Firefox."
say
say "  Cmd+L      address bar (centred dmenu prompt)"
say "  Cmd+F      find (/ prompt at the bottom)"
say "  Cmd+1..9   switch tab          Cmd+T new tab    Cmd+W close"
say "  Ctrl+Tab   next tab            Cmd+[ / Cmd+]    back / forward"
say
say "Tweak the knobs at the top of chrome/userChrome.css:"
say "  --mz-tabs-display: none      hide the tab strip entirely"
say "  --mz-traffic-lights: -moz-box   bring back the macOS window buttons"
