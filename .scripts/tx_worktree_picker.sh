#!/usr/bin/env bash
# Pick a dev-env git worktree via fzf and open/attach a tmux session
# for it with three windows:
#   1. nvim
#   2. claude (alias `c`, expanded by zsh -ic)
#   3. lazygit
# Mirrors the layout used by ~/.config/tx/templates/zapfloor-claude.yaml.

set -euo pipefail

WORKTREES="$HOME/code/work/dev-env/worktrees"
if [[ ! -d "$WORKTREES" ]]; then
  echo "no dev-env worktrees at $WORKTREES" >&2
  read -r -p "press enter to close..." _
  exit 1
fi

# Each worktree dir is <issue>/<repo>; collect them as relative paths.
choices=()
while IFS= read -r d; do
  [[ -d "$d" ]] || continue
  choices+=("${d#$WORKTREES/}")
done < <(find "$WORKTREES" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)

if [[ ${#choices[@]} -eq 0 ]]; then
  echo "no worktrees yet — create one with:" >&2
  echo "  ~/code/work/dev-env/scripts/setup-worktrees.sh <issue> --hq-api <branch> --operator-client <branch> --oc-2 <branch>" >&2
  read -r -p "press enter to close..." _
  exit 1
fi

choice="$(printf '%s\n' "${choices[@]}" \
  | fzf --prompt='worktree> ' --height=100% --reverse --no-info)"
[[ -n "$choice" ]] || exit 0

issue="${choice%%/*}"
repo="${choice##*/}"
session="${issue}-${repo}"
dir="$WORKTREES/$choice"

if tmux has-session -t "$session" 2>/dev/null; then
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$session"
  else
    tmux attach -t "$session"
  fi
  exit 0
fi

# Create the session detached, then layer on the other windows. Each
# window runs the default interactive shell and the start command is
# typed in via send-keys — mirroring how tx applies its templates
# (see applyTemplate in tx/src/templates.ts, ~/.config/tx/templates).
# Because the program isn't the window's root process, quitting nvim /
# claude / lazygit drops back to the shell instead of closing the
# window. With `renumber-windows on`, a closing window would otherwise
# reshuffle the remaining windows and lose the layout order.
tmux new-session -d -s "$session" -c "$dir" -n nvim
tmux send-keys   -t "$session:nvim"   "nvim" C-m

tmux new-window  -t "$session:" -c "$dir" -n claude
tmux send-keys   -t "$session:claude" "claude --dangerously-skip-permissions" C-m

tmux new-window  -t "$session:" -c "$dir" -n git
tmux send-keys   -t "$session:git"    "lazygit" C-m

tmux select-window -t "$session:nvim"

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$session"
else
  tmux attach -t "$session"
fi
