#!/usr/bin/env bash
# Tests for ~/dotfiles/.scripts/tmux_harpoon.sh — pure logic, fake `tmux`.
# Run: bash ~/dotfiles/test/tmux_harpoon_test.sh
set -uo pipefail

SCRIPT="$HOME/dotfiles/.scripts/tmux_harpoon.sh"
pass=0 fail=0

assert_eq() { # desc expected actual
  if [[ "$2" == "$3" ]]; then pass=$((pass+1)); printf 'ok   - %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL - %s\n      expected: %q\n      actual:   %q\n' "$1" "$2" "$3"; fi
}
assert_contains() { # desc needle haystack
  if [[ "$3" == *"$2"* ]]; then pass=$((pass+1)); printf 'ok   - %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL - %s\n      missing: %q\n      in:      %q\n' "$1" "$2" "$3"; fi
}

setup() {
  TMPD="$(mktemp -d)"
  export TMUX_HARPOON_FILE="$TMPD/list"
  export TMUX_CALLS="$TMPD/calls"; : > "$TMUX_CALLS"
  export FAKE_WINDOWS=""
  mkdir -p "$TMPD/bin"
  cat > "$TMPD/bin/tmux" <<'SHIM'
#!/usr/bin/env bash
# Fake tmux. FAKE_WINDOWS="sess:win sess:win2" = windows that exist.
case "$1" in
  list-windows)            # list-windows -t SESS -F '#{window_name}'
    sess="$3"
    for pair in $FAKE_WINDOWS; do
      [[ "${pair%%:*}" == "$sess" ]] && printf '%s\n' "${pair#*:}"
    done ;;
  switch-client|select-window)
    printf '%s %s %s\n' "$1" "$2" "$3" >> "$TMUX_CALLS" ;;
esac
SHIM
  chmod +x "$TMPD/bin/tmux"
  PATH="$TMPD/bin:$PATH"
  source "$SCRIPT"
}
teardown() { rm -rf "$TMPD"; }

# --- add / dedupe / trim ---
setup
harpoon_add "hq-api:server"
harpoon_add "hq-api:server"                       # dedupe
harpoon_add "  lm8352-operator-client:nvim  "     # trim
assert_eq "add dedupes + trims" \
  $'hq-api:server\nlm8352-operator-client:nvim' "$(harpoon_slots)"
teardown

# --- add tolerates a list file with no trailing newline ---
setup
printf 'hq-api:server' > "$TMUX_HARPOON_FILE"   # no trailing newline
harpoon_add "operator-client:nvim"
assert_eq "add does not merge lines w/o trailing newline" \
  $'hq-api:server\noperator-client:nvim' "$(harpoon_slots)"
teardown

# --- render + marker ---
setup
export FAKE_WINDOWS="hq-api:server"
harpoon_add "hq-api:server"
harpoon_add "dev-env:logs"
out="$(harpoon_render)"
assert_contains "render present marker" $'1\t  1  ● hq-api:server' "$out"
assert_contains "render stale marker"   $'2\t  2  ✗ dev-env:logs' "$out"
teardown

# --- render handles a window name containing a colon (split on first colon) ---
setup
export FAKE_WINDOWS="sess:my:win"
harpoon_add "sess:my:win"
assert_contains "render colon-in-winname" $'1\t  1  ● sess:my:win' "$(harpoon_render)"
teardown

# --- render on an empty list emits nothing ---
setup
assert_eq "render empty list is empty" "" "$(harpoon_render)"
teardown

# --- jump success ---
setup
export FAKE_WINDOWS="hq-api:server"
harpoon_add "hq-api:server"
harpoon_jump 1
assert_eq "jump emits switch-client" "switch-client -t hq-api" \
  "$(sed -n 1p "$TMUX_CALLS")"
assert_eq "jump emits select-window" "select-window -t hq-api:server" \
  "$(sed -n 2p "$TMUX_CALLS")"
teardown

# --- jump out of range ---
setup
harpoon_add "hq-api:server"
if harpoon_jump 5 2>/dev/null; then rc=0; else rc=1; fi
assert_eq "jump out-of-range nonzero" "1" "$rc"
teardown

# --- jump stale target ---
setup
export FAKE_WINDOWS=""
harpoon_add "hq-api:server"
err="$(harpoon_jump 1 2>&1)"; rc=$?
assert_eq "jump stale nonzero" "1" "$rc"
assert_contains "jump stale messages" "harpoon: target gone" "$err"
assert_eq "jump stale no tmux calls" "" "$(cat "$TMUX_CALLS")"
teardown

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
