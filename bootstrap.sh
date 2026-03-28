#!/usr/bin/env bash
# Bootstrap a fresh OrbStack NixOS VM from this repo.
#
# From inside the VM:
#   bash /mnt/mac/Users/iorlas/nixos-config/bootstrap.sh
#
# From macOS:
#   orb run -m pix bash /mnt/mac/Users/iorlas/nixos-config/bootstrap.sh

set -euo pipefail

REPO_MAC="/mnt/mac/Users/iorlas/nixos-config"

echo "==> Step 1: nixos-rebuild switch"

# Flakes need git; fresh NixOS doesn't have it
if ! command -v git &> /dev/null; then
  echo "    Installing git temporarily for flake evaluation..."
  export PATH="$(nix-build '<nixpkgs>' -A git --no-out-link)/bin:$PATH"
fi

# --impure needed because we import /etc/nixos/orbstack.nix (OrbStack-managed, not in repo)
sudo env PATH="$PATH" nixos-rebuild switch --flake "$REPO_MAC#pix" --impure

echo "==> Step 2: Install Claude Code"

mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g @anthropic-ai/claude-code

echo ""
echo "==> Done! Next steps:"
echo "    sudo tailscale up --exit-node=<vps-tailscale-ip> --accept-routes"
echo "    claude"
