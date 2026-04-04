#!/usr/bin/env bash
# Check: Nix installation

check_nix() {
  echo "==> Nix"
  if command -v nix &> /dev/null; then
    ok "$(nix --version)"
  else
    fail "Nix not installed"
    hint "Run: bootstrap"
  fi
}

check_nix_adhoc() {
  echo "==> Nix ad-hoc packages"
  local adhoc
  adhoc=$(nix-env -q 2>/dev/null || echo "")
  if [ -z "$adhoc" ]; then
    ok "No ad-hoc packages (clean)"
  else
    warn "Ad-hoc packages installed (not in config, add to home.packages to persist):"
    echo "$adhoc" | while read -r pkg; do
      echo -e "    ${YELLOW}•${NC} $pkg"
    done
  fi
}
