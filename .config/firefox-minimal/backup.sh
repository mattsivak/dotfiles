#!/usr/bin/env bash
#
# Snapshot / restore the minimal-chrome Firefox profile.
#
#   ./backup.sh                 # take a timestamped snapshot
#   ./backup.sh --list          # show snapshots
#   ./backup.sh --restore NAME  # restore one (refuses if Firefox is running)
#   ./backup.sh --prune N       # keep only the newest N snapshots
#
# Why this exists: installed extensions and their configuration live in the
# profile, not in this repo. The profile is deliberately NOT committed — it
# holds cookies, logins and session tokens — so it needs its own backup.

set -euo pipefail

STATE="$HOME/.local/share/firefox-minimal"
PROFILE="$STATE/try-profile"
SNAPS="$STATE/snapshots"

mkdir -p "$SNAPS"

list() {
  if ! ls -1 "$SNAPS" >/dev/null 2>&1 || [ -z "$(ls -A "$SNAPS" 2>/dev/null)" ]; then
    echo "no snapshots in $SNAPS"
    return
  fi
  for d in "$SNAPS"/*/; do
    n="$(basename "$d")"
    sz="$(du -sh "$d" 2>/dev/null | cut -f1)"
    ext="$(ls "$d/extensions/"*.xpi 2>/dev/null | grep -cv 'newtab@mozilla.org' || true)"
    printf '  %-28s %6s  %s extension(s)\n' "$n" "$sz" "${ext:-0}"
  done
}

case "${1:-}" in
  --list) list; exit 0 ;;

  --restore)
    name="${2:-}"
    [ -n "$name" ] || { echo "usage: $0 --restore NAME" >&2; list >&2; exit 2; }
    src="$SNAPS/$name"
    [ -d "$src" ] || { echo "no such snapshot: $name" >&2; list >&2; exit 1; }
    if pgrep -f "profile $PROFILE" >/dev/null 2>&1; then
      echo "Firefox is using that profile. Quit it first (Cmd+Q)." >&2
      exit 1
    fi
    # Never delete the current profile outright: park it, then restore.
    if [ -d "$PROFILE" ]; then
      parked="$STATE/replaced-$(date +%Y%m%d-%H%M%S)"
      mv "$PROFILE" "$parked"
      echo "current profile parked at: $parked"
    fi
    cp -a "$src" "$PROFILE"
    echo "restored $name -> $PROFILE"
    exit 0
    ;;

  --prune)
    keep="${2:-5}"
    cnt=0
    for d in $(ls -1dt "$SNAPS"/*/ 2>/dev/null); do
      cnt=$((cnt + 1))
      if [ "$cnt" -gt "$keep" ]; then
        echo "removing $(basename "$d")"
        rm -rf "$d"
      fi
    done
    echo "kept newest $keep"
    list
    exit 0
    ;;

  -h|--help)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

# --- default: take a snapshot ----------------------------------------------
[ -d "$PROFILE" ] || { echo "no profile at $PROFILE" >&2; exit 1; }

# A snapshot taken while Firefox runs can catch sqlite mid-write. The -wal and
# -shm sidecars are copied too (cp -a, whole directory), which is what keeps
# such a copy replayable rather than corrupt — but a clean snapshot is still
# better, so say so rather than pretending otherwise.
if pgrep -f "profile $PROFILE" >/dev/null 2>&1; then
  echo "note: Firefox is running; snapshotting live state."
  echo "      Quit it first for a guaranteed-clean copy."
fi

dest="$SNAPS/$(date +%Y%m%d-%H%M%S)"
cp -a "$PROFILE" "$dest"

ext="$(ls "$dest/extensions/"*.xpi 2>/dev/null | grep -cv 'newtab@mozilla.org' || true)"
echo "snapshot: $dest"
echo "          $(du -sh "$dest" | cut -f1), ${ext:-0} extension(s)"
echo
list
