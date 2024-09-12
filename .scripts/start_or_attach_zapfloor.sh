#!/bin/bash

# Check if the zapfloor session already exists
if tmux has-session -t zapfloor 2>/dev/null; then
  # If the session exists, attach to it in Alacritty
  alacritty -e tmux attach -t zapfloor
else
  # If the session doesn't exist, create it in detached mode, and then attach
  alacritty -e tmux new-session -d -s zapfloor \; \
    send-keys 'cd ~/code/work/zapfloor/hq-api; rails s' C-m \; \
    split-window -v \; \
    send-keys 'cd ~/code/work/zapfloor/hq-api; rake jobs:work' C-m \; \
    split-window -h \; \
    send-keys 'cd ~/code/work/zapfloor/operator-client; nvm exec 18 npm run dev' C-m \; \
    split-window -v \; \
    send-keys 'cd ~/code/work/zapfloor/oc-2/; npm run dev' C-m \; \
    select-layout tiled

  # Attach to the newly created session
  alacritty -e tmux attach -t zapfloor
fi
