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
