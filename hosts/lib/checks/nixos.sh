#!/usr/bin/env bash
# Check: NixOS (pix-specific)

check_nixos() {
  echo "==> NixOS"
  if [ -L /run/current-system ]; then
    local nixos_ver
    nixos_ver=$(nixos-version 2>/dev/null || echo "unknown")
    ok "NixOS $nixos_ver"
  else
    fail "Not running NixOS"
  fi
}
