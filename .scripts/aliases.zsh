alias zshconfig="nvim ~/.zshrc"
alias ohmyzsh="nvim ~/.oh-my-zsh"
alias zshreload="source ~/.zshrc"

alias cd="z"

alias zapfloorhq="cd ~/code/work/zapfloor/hq-api; rails s"
alias zapfloorhqjobs="cd ~/code/work/zapfloor/hq-api; rake jobs:work"
alias zapflooroperator="cd ~/code/work/zapfloor/operator-client; nvm exec 18 npm run dev"
alias zapflooroc2="cd ~/code/work/zapfloor/oc-2/; npm run dev"

alias startzapfloor="tmux rename-session zapfloor \; \
  send-keys 'cd ~/code/work/zapfloor/hq-api; rails s' C-m \; \
  split-window -v \; \
  send-keys 'cd ~/code/work/zapfloor/hq-api; rake jobs:work' C-m \; \
  split-window -h \; \
  send-keys 'cd ~/code/work/zapfloor/operator-client; nvm exec 18 npm run dev' C-m \; \
  split-window -v \; \
  send-keys 'cd ~/code/work/zapfloor/oc-2/; npm run dev' C-m \; \
  select-layout tiled \; \
  attach"
alias startzapfloord="tmux new-session -d -s zapfloor \; \
  send-keys 'cd ~/code/work/zapfloor/hq-api; rails s' C-m \; \
  split-window -v \; \
  send-keys 'cd ~/code/work/zapfloor/hq-api; rake jobs:work' C-m \; \
  split-window -h \; \
  send-keys 'cd ~/code/work/zapfloor/operator-client; nvm exec 18 npm run dev' C-m \; \
  split-window -v \; \
  send-keys 'cd ~/code/work/zapfloor/oc-2/; npm run dev' C-m \; \
  select-layout tiled"

alias stopzapfloor="tmux kill-session -t zapfloor"
