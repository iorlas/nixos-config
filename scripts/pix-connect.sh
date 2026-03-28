#!/usr/bin/env bash
# Connect to tmux sessions on pix via iTerm2 tmux -CC integration.
#
# Usage:
#   pix-connect                     # reconnect all existing sessions (or create default)
#   pix-connect project-name        # create/attach a project session
#   pix-connect project-name /path  # create in custom path
#
# Run this in an iTerm2 window. tmux -CC takes over and creates native windows.
# The terminal you run this in becomes the tmux control terminal.

set -uo pipefail

HOST="pix@orb"
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

# tmux -CC can attach to ALL sessions at once by connecting to any one —
# iTerm2 will restore windows for all sessions automatically
FIRST=$(echo "$SESSIONS" | head -1)
exec ssh "$HOST" -t "tmux -CC attach -t $FIRST"
