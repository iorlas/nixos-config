#!/usr/bin/env bash
# Setup portable configs on Mac. Idempotent — safe to re-run.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

echo "==> Claude plugin dirs"
mkdir -p "$HOME/.config/claude"
cat > "$HOME/.config/claude/plugin-dirs" << 'EOF'
~/Workspaces/iorlas-kay
~/Workspaces/iorlas-brainstorm
~/Workspaces/agent-harness
~/Documents/Knowledge/Skills
EOF
echo "  Written to ~/.config/claude/plugin-dirs"

echo "==> fox-connect"
mkdir -p "$HOME/.local/bin"
cp "$REPO/scripts/fox-connect.sh" "$HOME/.local/bin/fox-connect"
chmod +x "$HOME/.local/bin/fox-connect"
echo "  Installed to ~/.local/bin/fox-connect"

echo "==> SSH config check"
if grep -q "Host fox" "$HOME/.ssh/config" 2>/dev/null; then
  echo "  Host fox already configured"
else
  cat >> "$HOME/.ssh/config" << 'EOF'

Host fox
    HostName shen.iorlas.net
    Port 2201
    User fox
EOF
  echo "  Added Host fox to ~/.ssh/config"
fi

echo ""
echo "Done. Make sure ~/.local/bin is on your PATH."
