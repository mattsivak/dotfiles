#!/usr/bin/env bash
#
# Open the minimal chrome in a throwaway profile, alongside your real Firefox.
#
#   ./try.sh                 # fresh scratch profile, current CSS
#   ./try.sh --keep          # reuse the scratch profile (keeps history/tabs)
#
# Nothing here touches your real profile. Delete /tmp/ffmin-try to reset.
# Launching the binary directly with --no-remote --new-instance is what allows
# a second Firefox beside a running one; `open -a Firefox` would just focus the
# existing instance instead.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIREFOX="/Applications/Firefox.app/Contents/MacOS/firefox"
PROFILE="/tmp/ffmin-try"

KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

if [ "$KEEP" = 0 ] || [ ! -d "$PROFILE" ]; then
  rm -rf "$PROFILE"
  mkdir -p "$PROFILE/chrome"
  # Skip the first-run tour so the window opens straight into the chrome.
  cat > "$PROFILE/user.js" <<'EOF'
user_pref("browser.aboutwelcome.enabled", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("app.normandy.first_run", false);
EOF
fi

cp "$SRC/userChrome.css"  "$PROFILE/chrome/userChrome.css"
cp "$SRC/userContent.css" "$PROFILE/chrome/userContent.css"
# The delivered prefs go last so they win over the first-run suppressors above.
cat "$SRC/user.js" >> "$PROFILE/user.js"

echo "scratch profile: $PROFILE"
echo "opening..."
"$FIREFOX" --profile "$PROFILE" --no-remote --new-instance \
           --window-size 1200,780 about:blank \
           >/dev/null 2>&1 &
echo "pid $!"
echo
echo "Cmd+L address bar   Cmd+F find   Cmd+1..9 tabs   Cmd+Q to quit this one"
