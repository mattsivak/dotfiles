eval "$(starship init zsh)"

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

export ZSH="$HOME/.oh-my-zsh"

# TMUX setup
#ZSH_TMUX_AUTOSTART=true
#ZSH_TMUX_AUTOCONNECT=false

plugins=(git sudo zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

source ~/.scripts/aliases.zsh
source ~/.scripts/zapfloor_setup.zsh

eval "$(zoxide init zsh)"
export PATH="/Users/mattsivak/.rubies/ruby-3.1.4/bin/:$PATH"
export PATH=" /Applications/Postgres.app/Contents/Versions/latest/bin/:$PATH"

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
