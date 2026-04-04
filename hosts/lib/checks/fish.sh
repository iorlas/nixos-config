#!/usr/bin/env bash
# Check: Fish shell

check_fish() {
  echo "==> Fish Shell"
  if [ -x "$HOME/.nix-profile/bin/fish" ]; then
    ok "Fish available"
  else
    warn "Fish not found in nix profile"
    hint "Run: nrs (home-manager switch)"
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
