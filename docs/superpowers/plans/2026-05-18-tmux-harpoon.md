# tmux-harpoon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A harpoon-style, manually-curated focus list for tmux, bound to `prefix+u`, that lets the user pin `session:window` targets and flip between them from one fzf popup.

**Architecture:** A single sourceable bash script (`tmux_harpoon.sh`) holding pure list functions (add/slots/marker/render/jump/delete) plus a popup driver. Pure functions are unit-tested against a fake `tmux` on `PATH`; the fzf/popup layer is wired in one integration task and verified manually. tmux glue in `.tmux.conf` invokes it via `display-popup -E`, passing the origin `session`/`window` as FORMAT-expanded args.

**Tech Stack:** bash, fzf, tmux 3.x, nvim (user's full LazyVim config for the `e` edit action). Tests: plain bash runner (no bats/shellcheck — not installed in this repo).

---

## Spec

`docs/superpowers/specs/2026-05-18-tmux-harpoon-design.md` (read it before starting).

## File Structure

- **Create** `~/dotfiles/.scripts/tmux_harpoon.sh` — the whole tool. Sourceable: `set -euo pipefail` and `_harpoon_main` run only when executed (`BASH_SOURCE == $0`), so tests can source it safely.
- **Create** `~/dotfiles/test/tmux_harpoon_test.sh` — plain-bash test runner with a fake `tmux` shim.
- **Modify** `~/dotfiles/.tmux.conf` — `unbind u` + `bind u display-popup …`.

## Data / contracts (used across tasks — keep names exact)

- List file: `${TMUX_HARPOON_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux-harpoon/list}`. One `session:window` per line, line order = slot order.
- Functions: `_harpoon_file`, `harpoon_slots`, `harpoon_add <target>`, `harpoon_marker <target>`, `harpoon_render`, `harpoon_jump <N>`, `harpoon_delete <N>`, `_harpoon_msg <text>`, `_harpoon_deps`, `_harpoon_popup <sess> <win>`, `_harpoon_main "$@"`.
- Markers: `●` exists, `✗` stale.
- Test shim env: `TMUX_HARPOON_FILE` (temp list), `TMUX_CALLS` (file recording `switch-client`/`select-window` calls), `FAKE_WINDOWS` (space-separated `sess:win` that "exist").

## Preamble: branch (do once, before Task 1)

`~/dotfiles` is on `main` with **unrelated pre-existing dirty changes** (nvim config). Do **not** commit those. Branch first; every task commits **only the explicitly listed paths**.

- [ ] **Create the feature branch**

Run:
```bash
cd ~/dotfiles && git checkout -b feat/tmux-harpoon && git branch --show-current
```
Expected: prints `feat/tmux-harpoon`. (Dirty nvim files carry over untracked/modified — that is fine, we never `git add` them.)

---

### Task 1: List file, slots, add (+ dedupe/trim)

**Files:**
- Create: `~/dotfiles/test/tmux_harpoon_test.sh`
- Create: `~/dotfiles/.scripts/tmux_harpoon.sh`

- [ ] **Step 1: Write the failing test (full runner with first cases)**

Create `~/dotfiles/test/tmux_harpoon_test.sh`:

```bash
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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: FAIL — sourcing errors / `harpoon_add: command not found` (script does not exist yet).

- [ ] **Step 3: Create the script with file/slots/add**

Create `~/dotfiles/.scripts/tmux_harpoon.sh`:

```bash
#!/usr/bin/env bash
# tmux-harpoon — a curated focus list of session:window targets.
#
# Bound in ~/.tmux.conf:
#   unbind u
#   bind u display-popup -E -x C -y C -w 80% -h 70% \
#     "~/dotfiles/.scripts/tmux_harpoon.sh '#{session_name}' '#{window_name}'"
#
# One global list at $TMUX_HARPOON_FILE (default
# ${XDG_DATA_HOME:-~/.local/share}/tmux-harpoon/list), one `session:window` per line, line
# order = slot order. Inspired by ThePrimeagen/harpoon (harpoon2).
#
# Sourceable: strict mode + main run only when executed, so the bash test
# runner can source this file and call functions directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

_harpoon_file() {
  local f="${TMUX_HARPOON_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux-harpoon/list}"
  mkdir -p "$(dirname "$f")"
  [[ -e "$f" ]] || : > "$f"
  printf '%s\n' "$f"
}

# Trimmed, blank-free view of the list (one slot per line).
harpoon_slots() {
  local f; f="$(_harpoon_file)"
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$f" | grep -v '^$' || true
}

harpoon_add() {
  local target="${1:-}"
  target="${target#"${target%%[![:space:]]*}"}"   # ltrim
  target="${target%"${target##*[![:space:]]}"}"    # rtrim
  [[ -n "$target" ]] || return 0
  harpoon_slots | grep -Fxq -- "$target" && return 0   # dedupe
  local f; f="$(_harpoon_file)"
  # ensure existing content ends with a newline before appending
  [[ -s "$f" && -n "$(tail -c1 "$f")" ]] && printf '\n' >> "$f"
  printf '%s\n' "$target" >> "$f"
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: `ok   - add dedupes + trims` then `1 passed, 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add .scripts/tmux_harpoon.sh test/tmux_harpoon_test.sh \
  docs/superpowers/specs/2026-05-18-tmux-harpoon-design.md \
  docs/superpowers/plans/2026-05-18-tmux-harpoon.md
git commit -m "feat(tmux-harpoon): list file, slots, add with dedupe/trim

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Marker + render

**Files:**
- Modify: `~/dotfiles/.scripts/tmux_harpoon.sh`
- Modify: `~/dotfiles/test/tmux_harpoon_test.sh`

- [ ] **Step 1: Add the failing tests**

In `test/tmux_harpoon_test.sh`, insert **before** the final `printf '\n%d passed…'` block:

```bash
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
```

- [ ] **Step 2: Run, verify it fails**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: FAIL — `harpoon_render: command not found`.

- [ ] **Step 3: Implement marker + render**

In `tmux_harpoon.sh`, add after `harpoon_add`:

```bash
# ● if session:window currently exists, ✗ otherwise (stale, kept).
harpoon_marker() {
  local target="$1" sess win
  # split on the FIRST colon: session names cannot contain ':', window names can
  sess="${target%%:*}"; win="${target#*:}"
  if tmux list-windows -t "$sess" -F '#{window_name}' 2>/dev/null \
       | grep -Fxq -- "$win"; then
    printf '●'
  else
    printf '✗'
  fi
}

# Tab-delimited rows for fzf: "<N>\t<padded display>".
harpoon_render() {
  local i=0 line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    i=$((i+1))
    printf '%d\t%3d  %s %s\n' "$i" "$i" "$(harpoon_marker "$line")" "$line"
  done < <(harpoon_slots)
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: all `ok`, `3 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add .scripts/tmux_harpoon.sh test/tmux_harpoon_test.sh
git commit -m "feat(tmux-harpoon): marker + render

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Jump (success / out-of-range / stale)

**Files:**
- Modify: `~/dotfiles/.scripts/tmux_harpoon.sh`
- Modify: `~/dotfiles/test/tmux_harpoon_test.sh`

- [ ] **Step 1: Add the failing tests**

In `test/tmux_harpoon_test.sh`, insert before the final summary block:

```bash
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
if harpoon_jump 1 2>/dev/null; then rc=0; else rc=1; fi
assert_eq "jump stale nonzero" "1" "$rc"
assert_eq "jump stale no tmux calls" "" "$(cat "$TMUX_CALLS")"
teardown
```

- [ ] **Step 2: Run, verify it fails**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: FAIL — `harpoon_jump: command not found`.

- [ ] **Step 3: Implement msg + jump**

In `tmux_harpoon.sh`, add after `harpoon_render`:

```bash
_harpoon_msg() { printf '%s\n' "$*" >&2; }

# Switch to slot N. Returns nonzero (and messages) if N is invalid,
# out of range, or the target window no longer exists.
harpoon_jump() {
  local n="${1:-}" target sess win
  [[ "$n" =~ ^[0-9]+$ ]] || { _harpoon_msg "harpoon: invalid slot '$n'"; return 1; }
  target="$(harpoon_slots | sed -n "${n}p")"
  [[ -n "$target" ]] || { _harpoon_msg "harpoon: no slot $n"; return 1; }
  sess="${target%%:*}"; win="${target#*:}"
  if ! tmux list-windows -t "$sess" -F '#{window_name}' 2>/dev/null \
        | grep -Fxq -- "$win"; then
    _harpoon_msg "harpoon: target gone → $target"
    return 1
  fi
  tmux switch-client -t "$sess"
  tmux select-window -t "$sess:$win"
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: all `ok`, `8 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add .scripts/tmux_harpoon.sh test/tmux_harpoon_test.sh
git commit -m "feat(tmux-harpoon): jump with stale/range guards

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Delete

**Files:**
- Modify: `~/dotfiles/.scripts/tmux_harpoon.sh`
- Modify: `~/dotfiles/test/tmux_harpoon_test.sh`

- [ ] **Step 1: Add the failing test**

In `test/tmux_harpoon_test.sh`, insert before the final summary block:

```bash
# --- delete ---
setup
harpoon_add "a:1"; harpoon_add "b:2"; harpoon_add "c:3"
harpoon_delete 2
assert_eq "delete removes correct row" $'a:1\nc:3' "$(harpoon_slots)"
teardown
```

- [ ] **Step 2: Run, verify it fails**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: FAIL — `harpoon_delete: command not found`.

- [ ] **Step 3: Implement delete**

In `tmux_harpoon.sh`, add after `harpoon_jump`:

```bash
# Remove slot N (rewrites the file normalized: trimmed, blank-free).
harpoon_delete() {
  local n="${1:-}" f tmp
  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  f="$(_harpoon_file)"; tmp="$(mktemp)"
  harpoon_slots | sed "${n}d" > "$tmp"
  mv "$tmp" "$f"
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `bash ~/dotfiles/test/tmux_harpoon_test.sh`
Expected: all `ok`, `9 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add .scripts/tmux_harpoon.sh test/tmux_harpoon_test.sh
git commit -m "feat(tmux-harpoon): delete slot

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Popup driver, deps, main dispatch (integration — manual verify)

No unit test: this is the fzf/popup glue, verified manually per spec.

**Files:**
- Modify: `~/dotfiles/.scripts/tmux_harpoon.sh`

- [ ] **Step 1: Implement deps + popup + main + exec guard**

In `tmux_harpoon.sh`, add after `harpoon_delete`, then the exec guard at the **very end of the file**:

```bash
_harpoon_deps() {
  local missing=() dep
  for dep in fzf nvim tmux; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  if (( ${#missing[@]} )); then
    printf 'tmux-harpoon: missing dependency: %s\n' "${missing[*]}" >&2
    return 1
  fi
}

# fzf popup. Search disabled (curated list → digits act as jumps).
# `become` replaces fzf with `<self> jump N`; on success the tmux switch
# runs and the script exits, so display-popup -E tears the popup down.
_harpoon_popup() {
  export TMUX_HARPOON_ORIGIN="${1}:${2}"
  local self="${BASH_SOURCE[0]}" file i
  file="$(_harpoon_file)"
  local -a binds=(
    "--bind=enter:become(\"$self\" jump {1})"
    "--bind=a:execute-silent(\"$self\" add)+reload(\"$self\" _render)"
    "--bind=d:execute-silent(\"$self\" delete {1})+reload(\"$self\" _render)"
    "--bind=e:execute(nvim \"$file\")+reload(\"$self\" _render)"
    "--bind=q:abort"
  )
  for i in 1 2 3 4 5 6 7 8 9; do
    binds+=("--bind=$i:become(\"$self\" jump $i)")
  done
  harpoon_render | fzf \
    --ansi --no-sort --no-info --reverse --height=100% --disabled \
    --delimiter=$'\t' --with-nth=2 --prompt='harpoon> ' \
    --header='1-9 jump · enter jump · a add · d delete · e edit · q quit' \
    "${binds[@]}" || true
}

_harpoon_main() {
  case "${1:-}" in
    add)     harpoon_add "${TMUX_HARPOON_ORIGIN:-}" ;;
    jump)    if ! harpoon_jump "${2:-}"; then
               [[ -t 0 ]] && read -r -p "press enter to close..." _
             fi ;;
    delete)  harpoon_delete "${2:-}" ;;
    _render) harpoon_render ;;
    *)       _harpoon_deps || { read -r -p "press enter to close..." _; exit 1; }
             _harpoon_popup "${1:-}" "${2:-}" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _harpoon_main "$@"
fi
```

Note the documented limitation: an origin session literally named `add`/`jump`/`delete`/`_render` would be misrouted — acceptable (no such sessions exist; user names are `lm####-*`, `hq-api`, etc.).

- [ ] **Step 2: Make executable + sanity-check non-popup paths**

Run:
```bash
chmod +x ~/dotfiles/.scripts/tmux_harpoon.sh
bash ~/dotfiles/test/tmux_harpoon_test.sh        # still 9 passed (sourcing unaffected)
TMUX_HARPOON_FILE=/tmp/hp.$$ ~/dotfiles/.scripts/tmux_harpoon.sh _render; echo "rc=$?"
```
Expected: `9 passed, 0 failed`; `_render` prints nothing (empty list) with `rc=0`.

- [ ] **Step 3: Manual popup smoke test (inside a real tmux session)**

Run: `~/dotfiles/.scripts/tmux_harpoon.sh "$(tmux display -p '#{session_name}')" "$(tmux display -p '#{window_name}')"`
Verify, in order:
1. fzf popup opens with header `1-9 jump · enter jump · a add · d delete · e edit · q quit`.
2. Press `a` → current `session:window` appears as row `1 ●`.
3. Press `e` → full nvim opens on the list file; `:q` returns; list reloads.
4. Press `1` → popup closes and you are on that window (no-op if already there).
5. Re-open, press `d` on a row → it disappears.
6. `q` / `Esc` → popup closes, no error.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add .scripts/tmux_harpoon.sh
git commit -m "feat(tmux-harpoon): fzf popup, deps, main dispatch

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: tmux.conf binding + end-to-end verification

**Files:**
- Modify: `~/dotfiles/.tmux.conf` (insert after the `bind e` worktree block, currently lines 74-75)

- [ ] **Step 1: Add the binding**

Edit `~/.tmux.conf` — locate:

```
# dev-env worktree picker — fzf the running worktrees, open/attach a
# session with nvim / claude / lazygit windows.
unbind e
bind e display-popup -E -x C -y C -w 80% -h 70% "~/dotfiles/.scripts/tx_worktree_picker.sh"
```

Insert immediately **after** that block:

```

# tmux-harpoon — curated focus list of session:window targets (prefix u).
# Origin session/window are FORMAT-expanded before the popup runs so `a`
# (add current) records the right target.
unbind u
bind u display-popup -E -x C -y C -w 80% -h 70% "~/dotfiles/.scripts/tmux_harpoon.sh '#{session_name}' '#{window_name}'"
```

- [ ] **Step 2: Reload tmux config**

Run (inside tmux): `tmux source-file ~/.tmux.conf && tmux display-message "reloaded"` — or press `prefix r`.
Expected: `reloaded` flashes; no error in `tmux show-messages`.

- [ ] **Step 3: End-to-end verification**

1. `prefix u` → harpoon popup opens.
2. `a` from two different windows in different sessions → both appear, correct `session:window`.
3. `prefix u`, press `2` → jumps to slot 2's window in its session.
4. Kill one pinned session (`tmux kill-session -t <name>`), `prefix u` → that row shows `✗`, others `●`.
5. Press the digit of the `✗` row → message + "press enter to close…" then popup closes; no crash.
6. `e` → nvim, reorder lines, `:wq` → `prefix u` shows the new order.
7. Confirm nothing else regressed: `prefix w`, `prefix e`, `prefix s` still work.

- [ ] **Step 4: Final test run + commit**

```bash
cd ~/dotfiles
bash test/tmux_harpoon_test.sh                 # expect: 9 passed, 0 failed
git add .tmux.conf
git commit -m "feat(tmux-harpoon): bind prefix+u to the harpoon popup

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage**

| Spec requirement | Task |
|---|---|
| `prefix+u`, `unbind u` first, 80%×70% popup | Task 6 |
| Window-level `session:window` slots | Tasks 1-4 |
| Menu-driven only, single popup | Task 5 |
| One global list, extensionless file, whitespace-tolerant | Task 1 (`harpoon_slots` trims; default path extensionless) |
| `1-9` jump, `Enter` jump highlighted | Tasks 3, 5 |
| `a` add (idempotent dedupe) | Tasks 1, 5 |
| `d` delete highlighted | Tasks 4, 5 |
| `e` edit in full nvim, reload after | Task 5 |
| `q`/`Esc` close | Task 5 |
| `●`/`✗` marker, stale never auto-pruned | Task 2 (render reflects state; nothing prunes) |
| Jump resolution: switch-client + select-window; gone → message | Task 3 |
| Reusable `add`/`jump` subcommands | Task 5 (`_harpoon_main` dispatch) |
| bash test runner, no new deps | Tasks 1-4 |

No gaps. **Deviation flagged:** spec said gone-target should "stay open with message"; this plan shows the message then `read -p "press enter to close…"` then closes — matching the existing codebase convention (`tx_worktree_picker.sh`, `claude_ask_popup.sh`) and unavoidable with fzf `become`. Functionally equivalent (no accidental switch), codebase-consistent.

**2. Placeholder scan:** none — every code/command step is complete.

**3. Type consistency:** function names and the `TMUX_HARPOON_FILE` / `TMUX_CALLS` / `FAKE_WINDOWS` / `TMUX_HARPOON_ORIGIN` env names are identical across all tasks and the test runner. Tab-delimited render format `<N>\t%3d  <marker> <target>` consistent between Task 2 (impl), the Task 2/3 asserts, and the fzf `--delimiter`/`--with-nth=2`/`{1}` usage in Task 5.
