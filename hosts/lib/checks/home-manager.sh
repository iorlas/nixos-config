#!/usr/bin/env bash
# Check: Home Manager

check_home_manager() {
  echo "==> Home Manager"
  if command -v home-manager &> /dev/null; then
    local hm_gen
    hm_gen=$(home-manager generations 2>/dev/null | head -1 || echo "unknown")
    ok "Active: $hm_gen"
  elif [ -L "$HOME/.local/share/home-manager/gcroots/current-home" ]; then
    # NixOS module mode — no CLI binary but home-manager is active
    ok "Active (NixOS module mode)"
  else
    fail "home-manager not found"
    hint "Run: bootstrap"
  fi
}
