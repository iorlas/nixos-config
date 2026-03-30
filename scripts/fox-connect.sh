#!/usr/bin/env bash
# Connect to tmux sessions on fox via iTerm2 tmux -CC integration.
#
# Usage:
#   fox-connect                     # reconnect all existing sessions (or create default)
#   fox-connect project-name        # create/attach a project session
#   fox-connect project-name /path  # create in custom path
#
# Run this in an iTerm2 window. tmux -CC takes over and creates native windows.

set -uo pipefail

HOST="fox"
SESSION="${1:-}"
DIR="${2:-}"

# If a session name was given, create/attach just that one
if [ -n "$SESSION" ]; then
  DIR="${DIR:-~/Workspaces/$SESSION}"
  ssh "$HOST" "mkdir -p $DIR" 2>/dev/null
  echo "→ Connecting to $SESSION ($DIR)..."
  exec ssh "$HOST" -t "tmux -CC new-session -A -s $SESSION -c $DIR"
fi

# Otherwise, reconnect all existing sessions
SESSIONS=$(ssh "$HOST" "tmux list-sessions -F '#S'" 2>/dev/null || echo "")

if [ -z "$SESSIONS" ]; then
  echo "→ No sessions found. Creating default session..."
  exec ssh "$HOST" -t "tmux -CC new-session -s main"
fi

echo "→ Reconnecting $(echo "$SESSIONS" | wc -l | tr -d ' ') session(s)..."

FIRST=$(echo "$SESSIONS" | head -1)
exec ssh "$HOST" -t "tmux -CC attach -t $FIRST"
