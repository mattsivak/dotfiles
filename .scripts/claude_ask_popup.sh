#!/usr/bin/env bash
# Ask Claude from a tmux popup (prefix q).
#
# Bound in ~/.tmux.conf:
#   bind q display-popup -E -d "#{pane_current_path}" ... claude_ask_popup.sh
#
# gum input box for the question -> one-shot `claude -p` (Haiku) -> answer
# shown in bat's clean pager. Runs in the calling pane's directory so Claude
# has project context. `q` closes bat, the script ends, and -E closes the
# popup. Temp file removed via an EXIT trap -> clean teardown, no leftovers.

set -euo pipefail

missing=()
for dep in gum bat claude; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'Missing dependency: %s\n\n' "${missing[*]}" >&2
  printf 'Install with:\n  brew bundle --file ~/dotfiles/Brewfile\n\n' >&2
  read -r -p "press enter to close..." _
  exit 1
fi

# Esc / Ctrl-C from gum returns non-zero; treat that as an empty question.
question="$(gum input \
  --placeholder "Ask Claude…" \
  --prompt "❯ " \
  --char-limit 0 \
  --width 0 || true)"

# Nothing (or only whitespace) typed -> silent, clean exit. No Claude run.
[[ -n "${question//[[:space:]]/}" ]] || exit 0

tmp="$(mktemp "${TMPDIR:-/tmp}/claude_ask.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

# One-shot, non-interactive. Capture stdout+stderr so failures are visible
# in the answer view instead of vanishing.
set +e
gum spin --spinner dot --title "Asking Claude…" -- \
  bash -c 'claude -p --dangerously-skip-permissions --model haiku "$1" > "$2" 2>&1' _ "$question" "$tmp"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  printf '\n[claude exited with status %s]\n' "$status" >> "$tmp"
fi

# Clean paged view: question as the header, grid rules, no line-number
# noise, markdown-aware highlighting (source, not glamour-rendered). Not
# exec'd so the EXIT trap still fires after `q` closes bat -> -E closes
# the popup.
bat \
  --paging=always \
  --style=header,grid \
  --file-name "❯ ${question}" \
  --language=md \
  "$tmp"
