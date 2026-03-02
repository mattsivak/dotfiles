#!/bin/bash

# Kill existing sessions if they exist
tmux kill-session -t oc2 2>/dev/null
tmux kill-session -t operator-client 2>/dev/null
tmux kill-session -t user-client 2>/dev/null
tmux kill-session -t hq-api 2>/dev/null

# Create oc2 session
tmux new-session -d -s oc2 -c ~/code/work/oc-2
tmux send-keys -t oc2:1 'nvim' C-m
tmux new-window -t oc2 -c ~/code/work/oc-2
tmux send-keys -t oc2:2 'claude --dangerously-skip-permissions' C-m
tmux new-window -t oc2 -c ~/code/work/oc-2
tmux send-keys -t oc2:3 'lazygit' C-m
tmux new-window -t oc2 -c ~/code/work/oc-2
tmux send-keys -t oc2:4 'npx vitest' C-m
tmux new-window -t oc2 -c ~/code/work/oc-2
tmux send-keys -t oc2:5 'npm run dev' C-m

# Create operator-client session
tmux new-session -d -s operator-client -c ~/code/work/operator-client
tmux send-keys -t operator-client:1 'nvim' C-m
tmux new-window -t operator-client -c ~/code/work/operator-client
tmux send-keys -t operator-client:2 'claude --dangerously-skip-permissions' C-m
tmux new-window -t operator-client -c ~/code/work/operator-client
tmux send-keys -t operator-client:3 'lazygit' C-m
tmux new-window -t operator-client -c ~/code/work/operator-client
tmux new-window -t operator-client -c ~/code/work/operator-client
tmux send-keys -t operator-client:5 'npm run dev' C-m

# Create user-client session
tmux new-session -d -s user-client -c ~/code/work/user-client
tmux send-keys -t user-client:1 'nvim' C-m
tmux new-window -t user-client -c ~/code/work/user-client
tmux send-keys -t user-client:2 'claude --dangerously-skip-permissions' C-m
tmux new-window -t user-client -c ~/code/work/user-client
tmux send-keys -t user-client:3 'lazygit' C-m
tmux new-window -t user-client -c ~/code/work/user-client
tmux new-window -t user-client -c ~/code/work/user-client
tmux send-keys -t user-client:5 'npm run dev' C-m

# Create hq-api session
tmux new-session -d -s hq-api -c ~/code/work/hq-api
tmux send-keys -t hq-api:1 'nvim' C-m
tmux new-window -t hq-api -c ~/code/work/hq-api
tmux send-keys -t hq-api:2 'claude --dangerously-skip-permissions' C-m
tmux new-window -t hq-api -c ~/code/work/hq-api
tmux send-keys -t hq-api:3 'lazygit' C-m
tmux new-window -t hq-api -c ~/code/work/hq-api
tmux send-keys -t hq-api:4 'bundle exec rake jobs:work' C-m
tmux new-window -t hq-api -c ~/code/work/hq-api
tmux send-keys -t hq-api:5 'rails s' C-m

# Attach to oc2 session
tmux attach-session -t oc2