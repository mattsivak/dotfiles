eval "$(starship init zsh)"

export ZSH="$HOME/.oh-my-zsh"

# TMUX setup
ZSH_TMUX_AUTOSTART=true
ZSH_TMUX_AUTOCONNECT=false

plugins=(git sudo zsh-syntax-highlighting zsh-autosuggestions tmux)

source $ZSH/oh-my-zsh.sh

source ~/.scripts/aliases.zsh
source ~/.scripts/zapfloor_setup.zsh
source ~/.scripts/setup_of_cli_tools.sh

# Added by Windsurf
export PATH="/Users/mattsivak/.codeium/windsurf/bin:$PATH"

# bun completions
[ -s "/Users/mattsivak/.bun/_bun" ] && source "/Users/mattsivak/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/mattsivak/.lmstudio/bin"
