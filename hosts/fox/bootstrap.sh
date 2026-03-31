#!/usr/bin/env bash
# One-time setup for fox (bare user on shen). Idempotent — safe to re-run.
set -euo pipefail

REPO="$HOME/nixos-config"

echo "==> Nix"
if command -v nix &> /dev/null; then
  echo "  Already installed ($(nix --version))"
else
  echo "  Installing..."
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --no-confirm
fi

# Source nix
NIX_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
if [ -f "$NIX_PROFILE" ]; then
  . "$NIX_PROFILE"
else
  echo "ERROR: nix-daemon.sh not found at $NIX_PROFILE"
  exit 1
fi

echo "==> nixos-config"
if [ -d "$REPO" ]; then
  echo "  Already cloned, pulling..."
  git -C "$REPO" pull
else
  git clone https://github.com/iorlas/nixos-config.git "$REPO"
fi

echo "==> Home Manager"
if command -v home-manager &> /dev/null; then
  echo "  Switching..."
  home-manager switch --flake "$REPO#fox"
else
  echo "  First install..."
  nix run home-manager/master -- switch --flake "$REPO#fox"
fi

echo "==> SSH authorized keys"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
curl -fsSL https://github.com/iorlas.keys > "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
echo "  $(wc -l < "$HOME/.ssh/authorized_keys") keys installed"

echo "==> Bash → Fish trampoline"
if [ ! -f "$HOME/.bashrc" ] || ! grep -q "FISH_STARTED" "$HOME/.bashrc"; then
  cp "$REPO/hosts/fox/defaults/bashrc" "$HOME/.bashrc"
  echo "  Installed"
else
  echo "  Already configured"
fi

echo "==> Home directory permissions"
chmod 700 "$HOME"

echo "==> Workspace directories"
mkdir -p "$HOME/Documents" "$HOME/Workspaces"

echo "==> Claude Code"
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global" 2>/dev/null
export PATH="$HOME/.npm-global/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  echo "  Already installed ($(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"
else
  echo "  Installing..."
  npm install -g @anthropic-ai/claude-code
fi

echo "==> iTerm2 Shell Integration"
if [ -f "$HOME/.iterm2_shell_integration.fish" ]; then
  echo "  Already installed"
else
  echo "  Installing..."
  curl -fsSL https://iterm2.com/shell_integration/fish -o "$HOME/.iterm2_shell_integration.fish"
fi

echo ""
echo "==> Running doctor..."
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.nix-profile/bin:$PATH"
doctor

echo ""
echo "==> Manual steps remaining:"
echo "  1. tide configure    (set up fish prompt — fixes tide errors)"
echo "  2. gh auth login     (GitHub CLI authentication)"
echo "  3. claude            (Claude Code first-run auth)"
