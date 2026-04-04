#!/usr/bin/env bash
# Check: Fish shell

check_fish() {
  echo "==> Fish Shell"
  if command -v fish &> /dev/null; then
    ok "Fish available ($(which fish))"
  else
    warn "Fish not found on PATH"
    hint "Run: nrs"
  fi
}

check_fish_trampoline() {
  # Only needed on non-NixOS hosts where login shell is bash
  if [ -f "$HOME/.bashrc" ] && grep -q "FISH_STARTED" "$HOME/.bashrc"; then
    ok "Bash → Fish trampoline configured"
  else
    warn "Bash → Fish trampoline missing"
    hint "Run: cp ~/nixos-config/hosts/fox/defaults/bashrc ~/.bashrc"
  fi
}
