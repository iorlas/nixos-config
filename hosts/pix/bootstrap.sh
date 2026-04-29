#!/usr/bin/env bash
# One-time setup for pix (OrbStack NixOS VM). Idempotent — safe to re-run.
#
# Usage:
#   orb run -m pix bash /mnt/mac/Users/iorlas/Workspaces/nixos-config/hosts/pix/bootstrap.sh

set -euo pipefail

REPO="/mnt/mac/Users/iorlas/Workspaces/nixos-config"

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
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  echo "  Already installed ($(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"
else
  echo "  Installing..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo ""
echo "==> Running doctor..."
doctor

echo ""
echo "==> Manual steps remaining:"
echo "  1. tide configure    (set up fish prompt, first time only)"
echo "  2. gh auth login     (GitHub CLI authentication)"
echo "  3. claude            (Claude Code first-run auth)"
