#!/bin/bash

# Control Lightroom Classic's QoS (background or normal)
# Usage:
#   ./lightroom_qos.sh --set     # Set to background QoS (may prefer E-cores)
#   ./lightroom_qos.sh --revert  # Revert to default foreground QoS

APP_NAME="Lightroom Classic"

function get_pid() {
  pgrep -i "$APP_NAME"
}

function set_background() {
  PID=$(get_pid)
  if [ -z "$PID" ]; then
    echo "❌ $APP_NAME is not running."
    exit 1
  fi
  echo "✅ Found $APP_NAME with PID: $PID"
  echo "⚙️  Setting background QoS..."
  sudo taskpolicy -b -p "$PID" && echo "✅ Done."
}

function revert_policy() {
  PID=$(get_pid)
  if [ -z "$PID" ]; then
    echo "❌ $APP_NAME is not running."
    exit 1
  fi
  echo "✅ Found $APP_NAME with PID: $PID"
  echo "⚙️  Reverting to foreground QoS..."
  sudo taskpolicy -B -p "$PID" && echo "✅ Done."
}

case "$1" in
--set)
  set_background
  ;;
--revert)
  revert_policy
  ;;
*)
  echo "Usage: $0 --set | --revert"
  exit 1
  ;;
esac
