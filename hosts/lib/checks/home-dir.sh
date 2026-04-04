#!/usr/bin/env bash
# Check: Home directory permissions

check_home_permissions() {
  echo "==> Home directory"
  local perms
  perms=$(stat -c '%a' "$HOME" 2>/dev/null || stat -f '%Lp' "$HOME" 2>/dev/null)
  if [ "$perms" = "700" ]; then
    ok "Permissions: 700 (private)"
  else
    fix_or_hint "Permissions: $perms (should be 700)" "chmod 700 $HOME"
  fi
}
