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
