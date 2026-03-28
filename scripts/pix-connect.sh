#!/usr/bin/env bash
# Reconnect all tmux sessions on pix as native iTerm2 windows (tmux -CC).
# Or create a new project session.
#
# Usage:
#   pix-connect                     # reconnect all existing sessions
#   pix-connect project-name        # create/attach a project session
#   pix-connect project-name /path  # create in custom path

set -uo pipefail

HOST="pix@orb"
SESSION="${1:-}"
DIR="${2:-}"

open_iterm_tmux() {
  local cmd="$1"
  osascript -e "
    tell application \"iTerm2\"
      activate
      set newWindow to (create window with default profile)
      tell current session of newWindow
        write text \"$cmd\"
      end tell
    end tell
  " 2>/dev/null
}

# If a session name was given, create/attach just that one
if [ -n "$SESSION" ]; then
  DIR="${DIR:-~/Workspaces/$SESSION}"
  # Ensure directory exists on pix
  ssh "$HOST" "mkdir -p $DIR" 2>/dev/null
  echo "→ $SESSION ($DIR)"
  open_iterm_tmux "ssh $HOST -t 'tmux -CC new-session -A -s $SESSION -c $DIR'"
  exit 0
fi

# Otherwise, reconnect all existing sessions
SESSIONS=$(ssh "$HOST" "tmux list-sessions -F '#S'" 2>/dev/null || echo "")

if [ -z "$SESSIONS" ]; then
  echo "No sessions found. Creating default session..."
  open_iterm_tmux "ssh $HOST -t 'tmux -CC new-session -s main'"
  exit 0
fi

echo "Reconnecting sessions on pix:"
for SESSION in $SESSIONS; do
  echo "  → $SESSION"
  open_iterm_tmux "ssh $HOST -t 'tmux -CC attach -t $SESSION'"
  sleep 0.5
done

echo "Done. $(echo "$SESSIONS" | wc -l | tr -d ' ') session(s) reconnected."
