#!/usr/bin/env bash
# Health check for fox (bare user on shen).
# Use --fix to auto-fix what can be fixed.
set -uo pipefail

FIX=false
[[ "${1:-}" == "--fix" ]] && FIX=true

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'
ISSUES=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}→${NC} $1"; ISSUES=$((ISSUES + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ISSUES=$((ISSUES + 1)); }
hint() { echo -e "    ${DIM}$1${NC}"; }

fix_or_hint() {
  # $1 = hint message, $2 = fix command
  if $FIX; then
    echo -e "  ${YELLOW}→${NC} Fixing: $2"
    if eval "$2"; then
      ok "Fixed"
    else
      fail "Fix failed"
    fi
  else
    warn "$1"
    hint "$2"
  fi
}

# ─── Nix ──────────────────────────────────────────────────────────────────────

echo "==> Nix"
if command -v nix &> /dev/null; then
  ok "$(nix --version)"
else
  fail "Nix not installed"
  hint "Run: bootstrap"
fi

# ─── Home Manager ─────────────────────────────────────────────────────────────

echo "==> Home Manager"
if command -v home-manager &> /dev/null; then
  HM_GEN=$(home-manager generations 2>/dev/null | head -1 || echo "unknown")
  ok "Active: $HM_GEN"
else
  fail "home-manager not on PATH"
  hint "Run: bootstrap"
fi

# ─── Claude Code ───────────────────────────────────────────────────────────────

echo "==> Claude Code"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  CLAUDE_VER=$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ok "Installed ($CLAUDE_VER)"
else
  fail "Not installed"
  hint "Run: npm install -g @anthropic-ai/claude-code"
fi

if [ -d "$HOME/.claude" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
  ok "Authenticated"
else
  warn "Not authenticated"
  hint "Run: claude (first-run opens browser auth)"
fi

if [ -f "$HOME/.claude/settings.json" ] && grep -q "kay-statusline" "$HOME/.claude/settings.json"; then
  ok "Statusline configured"
else
  fix_or_hint "Statusline not configured in settings.json" \
    "mkdir -p $HOME/.claude && cat > $HOME/.claude/settings.json << 'SETTINGS'
{
  \"permissions\": {
    \"defaultMode\": \"bypassPermissions\"
  },
  \"statusLine\": {
    \"type\": \"command\",
    \"command\": \"bash ~/.claude/hooks/kay-statusline.sh\"
  }
}
SETTINGS"
fi

# ─── GitHub CLI ───────────────────────────────────────────────────────────────

echo "==> GitHub CLI"
if command -v gh &> /dev/null; then
  if gh auth status &>/dev/null; then
    GH_USER=$(gh api user -q .login 2>/dev/null || echo "unknown")
    ok "Authenticated as $GH_USER"
  else
    warn "Not authenticated"
    hint "Run: gh auth login"
  fi
else
  fail "gh not installed"
fi

# ─── Docker ────────────────────────────────────────────────────────────────────

echo "==> Docker"
if command -v docker &> /dev/null; then
  if docker info &>/dev/null; then
    ok "Docker $(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  else
    warn "Docker not accessible (check group membership)"
    hint "Run: sudo usermod -aG docker fox && newgrp docker"
  fi
else
  warn "Docker not found on PATH"
fi

# ─── SSH Keys ─────────────────────────────────────────────────────────────────

echo "==> SSH Keys"
if [ -f "$HOME/.ssh/authorized_keys" ]; then
  KEY_COUNT=$(wc -l < "$HOME/.ssh/authorized_keys")
  ok "$KEY_COUNT authorized key(s)"
else
  warn "No authorized_keys"
  hint "Run: curl -fsSL https://github.com/iorlas.keys > ~/.ssh/authorized_keys"
fi

# ─── Fish Shell ───────────────────────────────────────────────────────────────

echo "==> Fish Shell"
if [ -x "$HOME/.nix-profile/bin/fish" ]; then
  ok "Fish available"
else
  warn "Fish not found in nix profile"
  hint "Run: nrs (home-manager switch)"
fi

if [ -f "$HOME/.bashrc" ] && grep -q "FISH_STARTED" "$HOME/.bashrc"; then
  ok "Bash → Fish trampoline configured"
else
  warn "Bash → Fish trampoline missing"
  hint "Run: cp ~/nixos-config/hosts/fox/defaults/bashrc ~/.bashrc"
fi

# ─── Home directory ───────────────────────────────────────────────────────────

echo "==> Home directory"
PERMS=$(stat -c '%a' "$HOME" 2>/dev/null || stat -f '%Lp' "$HOME" 2>/dev/null)
if [ "$PERMS" = "700" ]; then
  ok "Permissions: 700 (private)"
else
  warn "Permissions: $PERMS (should be 700)"
  hint "Run: chmod 700 $HOME"
fi

# ─── Nix ad-hoc packages ─────────────────────────────────────────────────────

echo "==> Nix ad-hoc packages"
ADHOC=$(nix-env -q 2>/dev/null || echo "")
if [ -z "$ADHOC" ]; then
  ok "No ad-hoc packages (clean)"
else
  warn "Ad-hoc packages installed (not in config, add to home.packages to persist):"
  echo "$ADHOC" | while read -r pkg; do
    echo -e "    ${YELLOW}•${NC} $pkg"
  done
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}All good.${NC}"
else
  echo -e "${YELLOW}$ISSUES issue(s) found.${NC}"
fi
