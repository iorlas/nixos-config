# Fish completions for pix-connect
# Completes with existing tmux sessions + workspace directories on pix

complete -c pix-connect -f -a '(orb run -m pix tmux list-sessions -F "#S" 2>/dev/null)'
complete -c pix-connect -f -a '(orb run -m pix ls ~/Workspaces/ 2>/dev/null)'
