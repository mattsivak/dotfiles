# Brewfile — Homebrew dependency manifest for these dotfiles.
#
# Install everything with:
#   brew bundle --file ~/dotfiles/Brewfile
#
# Not exhaustive yet: this captures the tools the dotfiles' scripts and
# config directly depend on. Regenerate a full snapshot of the machine
# anytime with:
#   brew bundle dump --file ~/dotfiles/Brewfile --force

# --- core CLI tools (referenced by config / README setup) ---
brew "tmux"      # terminal multiplexer (prefix C-f)
brew "neovim"    # editor (LazyVim config)
brew "fzf"       # fuzzy finder (tx_worktree_picker.sh, tms)
brew "zoxide"    # smart cd (.scripts/setup_of_cli_tools.sh)
brew "stow"      # dotfiles symlink manager (README setup)
brew "starship"  # shell prompt

# --- claude_ask_popup.sh (prefix q): ask Claude from a tmux popup ---
brew "gum"       # question input box
brew "bat"       # clean pager for Claude's answer
