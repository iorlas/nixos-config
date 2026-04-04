#!/usr/bin/env bash
# Check: GitHub CLI

check_gh() {
  echo "==> GitHub CLI"
  if command -v gh &> /dev/null; then
    if gh auth status &>/dev/null; then
      local gh_user
      gh_user=$(gh api user -q .login 2>/dev/null || echo "unknown")
      ok "Authenticated as $gh_user"
    else
      warn "Not authenticated"
      hint "Run: gh auth login"
    fi
  else
    fail "gh not installed"
  fi
}
