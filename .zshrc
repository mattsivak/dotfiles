
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git sudo zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

source ~/.scripts/aliases.zsh
source ~/.scripts/zapfloor_setup.zsh
source ~/.scripts/setup_of_cli_tools.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

. "/Users/mattsivak/.deno/env"
# Add deno completions to search path
if [[ ":$FPATH:" != *":/Users/mattsivak/.zsh/completions:"* ]]; then export FPATH="/Users/mattsivak/.zsh/completions:$FPATH"; fi

# Initialize zsh completions (added by deno install script)
autoload -Uz compinit
compinit

export PATH="$HOME/.cargo/bin:$PATH"
