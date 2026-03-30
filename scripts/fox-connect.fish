# Fish completions for fox-connect
# Completes with existing tmux sessions + workspace directories on fox

complete -c fox-connect -f -a '(ssh fox tmux list-sessions -F "#S" 2>/dev/null)'
complete -c fox-connect -f -a '(ssh fox ls ~/Workspaces/ 2>/dev/null)'
