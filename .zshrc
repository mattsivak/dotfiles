
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

