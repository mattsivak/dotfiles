eval "$(starship init zsh)"



export ZSH="$HOME/.oh-my-zsh"

# TMUX setup
#ZSH_TMUX_AUTOSTART=true
#ZSH_TMUX_AUTOCONNECT=false

plugins=(git sudo zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

source ~/.scripts/aliases.zsh
source ~/.scripts/zapfloor_setup.zsh

eval "$(zoxide init zsh)"
# Ruby PATH now managed by chruby auto-switching
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

# Added by Windsurf
export PATH="/Users/mattsivak/.codeium/windsurf/bin:$PATH"

# bun completions
[ -s "/Users/mattsivak/.bun/_bun" ] && source "/Users/mattsivak/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

#autoload -U +X bashcompinit && bashcompinit
#complete -o nospace -C /opt/homebrew/bin/weed weed


# Herd injected PHP 8.4 configuration.
export HERD_PHP_84_INI_SCAN_DIR="/Users/mattsivak/Library/Application Support/Herd/config/php/84/"


# Herd injected PHP binary.
export PATH="/Users/mattsivak/Library/Application Support/Herd/bin/":$PATH


[[ -f "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh" ]] && builtin source "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh"

# Added by Windsurf
export PATH="/Users/mattsivak/.codeium/windsurf/bin:$PATH"

# Added by Windsurf
export PATH="/Users/mattsivak/.codeium/windsurf/bin:$PATH"

export PATH=$HOME//opt/homebrew/Cellar/erlang/27.3.4/lib/erlang/erts-15.2.7/bin:$PATH
export PATH=$HOME//opt/homebrew/bin:$PATH

alias lightroomQOS="zsh /Users/mattsivak/.scripts/lightroom_qos.sh"

# chruby version manager (replaces asdf for Ruby)
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh

# opencode
export PATH=/Users/mattsivak/.opencode/bin:$PATH

export PATH="/Users/mattsivak/Library/Python/3.9/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/mattsivak/.lmstudio/bin"
# End of LM Studio CLI section

