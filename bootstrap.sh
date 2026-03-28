#!/usr/bin/env bash
# One-time setup for pix (OrbStack NixOS VM). Idempotent — safe to re-run.
#
# Usage:
#   orb run -m pix bash /mnt/mac/Users/iorlas/nixos-config/bootstrap.sh

set -euo pipefail

REPO="/mnt/mac/Users/iorlas/nixos-config"

echo "==> Git"
if command -v git &> /dev/null; then
  echo "  Already installed"
else
  echo "  Installing temporarily for flake evaluation..."
  export PATH="$(nix-build '<nixpkgs>' -A git --no-out-link)/bin:$PATH"
fi

echo "==> NixOS rebuild"
sudo env PATH="$PATH" nixos-rebuild switch --flake "$REPO#pix" --impure

echo "==> Claude Code"
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global" 2>/dev/null
export PATH="$HOME/.npm-global/bin:$PATH"
if command -v claude &> /dev/null; then
  echo "  Already installed ($(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"
else
  echo "  Installing..."
  npm install -g @anthropic-ai/claude-code
fi

echo ""
echo "==> Running doctor..."
bash "$REPO/doctor.sh"
