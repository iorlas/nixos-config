#!/usr/bin/env bash
# Check: Home Manager

check_home_manager() {
  echo "==> Home Manager"
  if command -v home-manager &> /dev/null; then
    local hm_gen
    hm_gen=$(home-manager generations 2>/dev/null | head -1 || echo "unknown")
    ok "Active: $hm_gen"
  else
    fail "home-manager not on PATH"
    hint "Run: bootstrap"
  fi
}
