#!/usr/bin/env bash
# tmux-harpoon — a curated focus list of session:window targets.
#
# Bound in ~/.tmux.conf:
#   unbind u
#   bind u display-popup -E -x C -y C -w 80% -h 70% \
#     "~/dotfiles/.scripts/tmux_harpoon.sh"
# (tmux does NOT expand #{...} in a display-popup shell-command, so the
#  origin session:window is resolved inside the script via display-message.)
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
  case "$target" in *'#{'*) return 0 ;; esac           # reject unexpanded tmux format
  [[ "$target" == *:* ]] || return 0                   # must be session:window
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

_harpoon_msg() { printf '%s\n' "$*" >&2; }

# session:window of the client that opened the popup. tmux does NOT expand
# #{...} in a display-popup shell-command, so the origin must be resolved
# here rather than passed in as an argument.
_harpoon_origin() {
  tmux display-message -p '#{session_name}:#{window_name}' 2>/dev/null || true
}

# Switch to slot N. Returns nonzero (and messages) if N is invalid,
# out of range, or the target window no longer exists.
harpoon_jump() {
  local n="${1:-}" target sess win
  [[ "$n" =~ ^[0-9]+$ ]] || { _harpoon_msg "harpoon: invalid slot '$n'"; return 1; }
  target="$(harpoon_slots | sed -n "${n}p")"
  [[ -n "$target" ]] || { _harpoon_msg "harpoon: no slot $n"; return 1; }
  # split on the FIRST colon: session names cannot contain ':', window names can
  sess="${target%%:*}"; win="${target#*:}"
  if ! tmux list-windows -t "$sess" -F '#{window_name}' 2>/dev/null \
        | grep -Fxq -- "$win"; then
    _harpoon_msg "harpoon: target gone → $target"
    return 1
  fi
  tmux switch-client -t "$sess"
  tmux select-window -t "$sess:$win"
}

# Remove slot N (rewrites the file normalized: trimmed, blank-free).
harpoon_delete() {
  local n="${1:-}" f tmp
  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  f="$(_harpoon_file)"
  tmp="$(mktemp "$(dirname -- "$f")/.harpoon.XXXXXX")" || return 1
  if harpoon_slots | sed "${n}d" > "$tmp"; then
    mv "$tmp" "$f"
  else
    rm -f "$tmp"
    return 1
  fi
}

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
  export TMUX_HARPOON_ORIGIN="$(_harpoon_origin)"
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
    add)     harpoon_add "${TMUX_HARPOON_ORIGIN:-$(_harpoon_origin)}" ;;
    jump)    if ! harpoon_jump "${2:-}"; then
               [[ -t 0 ]] && read -r -p "press enter to close..." _
               exit 1
             fi ;;
    delete)  harpoon_delete "${2:-}" ;;
    _render) harpoon_render ;;
    *)       _harpoon_deps || { read -r -p "press enter to close..." _; exit 1; }
             _harpoon_popup ;;
  esac
}

# (paired with the strict-mode guard at the top) run main only when executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _harpoon_main "$@"
fi
