#!/usr/bin/env bash
#
# Open the minimal chrome in a scratch profile, alongside your real Firefox.
#
#   ./try.sh                 # reuse the scratch profile (keeps extensions!)
#   ./try.sh --fresh         # wipe and start clean (asks first if data exists)
#   ./try.sh --promote       # copy the scratch profile somewhere permanent
#
# The scratch profile lives OUTSIDE /tmp on purpose: macOS prunes /tmp, so a
# profile there loses installed extensions and their configuration on reboot.
#
# Launching the binary directly with --no-remote --new-instance is what allows
# a second Firefox beside a running one; `open -a Firefox` would just focus the
# existing instance instead.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIREFOX="/Applications/Firefox.app/Contents/MacOS/firefox"
STATE="$HOME/.local/share/firefox-minimal"
PROFILE="$STATE/try-profile"
LEGACY="/tmp/ffmin-try"

FRESH=0
PROMOTE=0
case "${1:-}" in
  --fresh)   FRESH=1 ;;
  --promote) PROMOTE=1 ;;
  --keep)    ;;                   # back-compat: reuse is now the default
  "")        ;;
  -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

mkdir -p "$STATE"

# --- one-time rescue: adopt a profile left in the old /tmp location ---------
if [ ! -d "$PROFILE" ] && [ -d "$LEGACY" ]; then
  echo "Found a scratch profile in /tmp (which macOS prunes)."
  echo "Moving it somewhere durable: $PROFILE"
  cp -a "$LEGACY" "$PROFILE"
  echo "Copied. The old /tmp copy is left alone; delete it when you're happy."
fi

count_addons() {
  ls "$PROFILE/extensions/"*.xpi 2>/dev/null | grep -cv 'newtab@mozilla.org' || true
}

# --- promote: hand the scratch profile to a named, permanent one ------------
if [ "$PROMOTE" = 1 ]; then
  [ -d "$PROFILE" ] || { echo "nothing to promote: $PROFILE missing" >&2; exit 1; }
  DEST="$STATE/profile"
  if [ -d "$DEST" ]; then
    echo "$DEST already exists; refusing to overwrite." >&2
    echo "Move or remove it first." >&2
    exit 1
  fi
  cp -a "$PROFILE" "$DEST"
  echo "Promoted to: $DEST"
  echo "Launch it with:"
  echo "  $FIREFOX --profile \"$DEST\" --no-remote --new-instance"
  exit 0
fi

# --- fresh: destructive, so refuse to do it silently ------------------------
if [ "$FRESH" = 1 ] && [ -d "$PROFILE" ]; then
  n="$(count_addons)"
  if [ "${n:-0}" -gt 0 ]; then
    echo "WARNING: $PROFILE has $n extension(s) installed:"
    ls "$PROFILE/extensions/"*.xpi 2>/dev/null \
      | grep -v 'newtab@mozilla.org' | xargs -n1 basename | sed 's/^/  /'
    echo
    printf 'Wipe them and start fresh? [y/N] '
    read -r reply
    case "$reply" in
      [yY]*) ;;
      *) echo "Aborted. (Run without --fresh to reuse the profile.)"; exit 1 ;;
    esac
  fi
  rm -rf "$PROFILE"
fi

# --- build / refresh the profile -------------------------------------------
NEW=0
if [ ! -d "$PROFILE" ]; then
  NEW=1
  mkdir -p "$PROFILE"
fi
mkdir -p "$PROFILE/chrome"

# user.js is regenerated every run so CSS/pref edits land, but it is the ONLY
# thing rewritten — extensions, logins and their settings are never touched.
{
  cat <<'EOF'
// Written by try.sh on every launch. Suppresses the first-run tour; the
// delivered prefs are appended below and win where they overlap.
user_pref("browser.aboutwelcome.enabled", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("app.normandy.first_run", false);
EOF
  cat "$SRC/user.js"
} > "$PROFILE/user.js"

cp "$SRC/userChrome.css"  "$PROFILE/chrome/userChrome.css"
cp "$SRC/userContent.css" "$PROFILE/chrome/userContent.css"

if pgrep -f "profile $PROFILE" >/dev/null 2>&1; then
  echo "That profile is already running — focus the existing window." >&2
  echo "(Quit it with Cmd+Q first if you want to reload changed CSS.)" >&2
  exit 1
fi

echo "scratch profile: $PROFILE"
[ "$NEW" = 1 ] && echo "(created fresh)" || echo "($(count_addons) extension(s) preserved)"
echo "opening..."
"$FIREFOX" --profile "$PROFILE" --no-remote --new-instance \
           --window-size 1200,780 about:blank \
           >/dev/null 2>&1 &
echo "pid $!"
echo
echo "Cmd+L address bar   Cmd+F find   Cmd+1..9 tabs   Cmd+Q to quit this one"
