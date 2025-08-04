#!/bin/bash

# Kill existing sessions if they exist
tmux kill-session -t oc2 2>/dev/null
tmux kill-session -t operator-client 2>/dev/null
tmux kill-session -t user-client 2>/dev/null
tmux kill-session -t hq-api 2>/dev/null

# Create oc2 session
tmux new-session -d -s oc2 -c ~/code/work/zapfloor/oc-2
tmux send-keys -t oc2:1 'nvim' C-m
tmux new-window -t oc2 -c ~/code/work/zapfloor/oc-2
tmux send-keys -t oc2:2 'lazygit' C-m
tmux new-window -t oc2 -c ~/code/work/zapfloor/oc-2
tmux send-keys -t oc2:3 'npx vitest' C-m
tmux new-window -t oc2 -c ~/code/work/zapfloor/oc-2
tmux send-keys -t oc2:4 'npm run dev' C-m

# Create operator-client session
tmux new-session -d -s operator-client -c ~/code/work/zapfloor/operator-client
tmux send-keys -t operator-client:1 'nvim' C-m
tmux new-window -t operator-client -c ~/code/work/zapfloor/operator-client
tmux send-keys -t operator-client:2 'lazygit' C-m
tmux new-window -t operator-client -c ~/code/work/zapfloor/operator-client
tmux new-window -t operator-client -c ~/code/work/zapfloor/operator-client
tmux send-keys -t operator-client:4 'nvm exec 18 npm run dev' C-m

# Create user-client session
tmux new-session -d -s user-client -c ~/code/work/zapfloor/user-client
tmux send-keys -t user-client:1 'nvim' C-m
tmux new-window -t user-client -c ~/code/work/zapfloor/user-client
tmux send-keys -t user-client:2 'lazygit' C-m
tmux new-window -t user-client -c ~/code/work/zapfloor/user-client
tmux new-window -t user-client -c ~/code/work/zapfloor/user-client
tmux send-keys -t user-client:4 'npm run dev' C-m

# Create hq-api session
tmux new-session -d -s hq-api -c ~/code/work/zapfloor/hq-api
tmux send-keys -t hq-api:1 'nvim' C-m
tmux new-window -t hq-api -c ~/code/work/zapfloor/hq-api
tmux send-keys -t hq-api:2 'lazygit' C-m
tmux new-window -t hq-api -c ~/code/work/zapfloor/hq-api
tmux send-keys -t hq-api:3 'bundle exec rake jobs:work' C-m
tmux new-window -t hq-api -c ~/code/work/zapfloor/hq-api
tmux send-keys -t hq-api:4 'rails s' C-m

# Attach to oc2 session
tmux attach-session -t oc2