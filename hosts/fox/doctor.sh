#!/usr/bin/env bash
# Health check for fox (Docker dev container).
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

# ─── Nix ──────────────────────────────────────────────────────────────────────

echo "==> Nix"
if command -v nix &> /dev/null; then
  NIX_VER=$(nix --version 2>/dev/null || echo "unknown")
  ok "$NIX_VER"
else
  fail "Nix not installed"
fi

# ─── Home Manager ─────────────────────────────────────────────────────────────

echo "==> Home Manager"
if command -v home-manager &> /dev/null; then
  HM_GEN=$(home-manager generations 2>/dev/null | head -1 || echo "unknown")
  ok "Active: $HM_GEN"
else
  fail "home-manager not on PATH"
  hint "Run: nix run home-manager/master -- switch --flake ~/nixos-config#fox"
fi

# ─── Claude Code ───────────────────────────────────────────────────────────────

echo "==> Claude Code"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  CLAUDE_VER=$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ok "Installed ($CLAUDE_VER)"
else
  fail "Not installed"
  hint "Run: pnpm add -g @anthropic-ai/claude-code"
fi

if [ -d "$HOME/.claude" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
  ok "Authenticated"
else
  warn "Not authenticated"
  hint "Run: claude (first-run opens browser auth)"
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
    hint "Choose: GitHub.com → HTTPS → Login with browser"
  fi
else
  fail "gh not installed"
fi

# ─── Docker ────────────────────────────────────────────────────────────────────

echo "==> Docker"
if command -v docker &> /dev/null; then
  if docker info &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    ok "Docker $DOCKER_VER"
  else
    fail "Docker daemon not responding"
    hint "Check: systemctl status docker"
  fi
else
  fail "Docker not installed"
fi

# ─── SSH ──────────────────────────────────────────────────────────────────────

echo "==> SSH"
if systemctl is-active --quiet ssh 2>/dev/null; then
  ok "sshd running"
else
  fail "sshd not running"
  hint "Check: systemctl status ssh"
fi

# ─── cgroup ───────────────────────────────────────────────────────────────────

echo "==> cgroup"
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  ok "cgroupv2 available"
else
  warn "cgroupv2 not detected — systemd may have issues"
fi

# ─── Nix ad-hoc packages ─────────────────────────────────────────────────────

echo "==> Nix ad-hoc packages"
ADHOC=$(nix-env -q 2>/dev/null || echo "")
if [ -z "$ADHOC" ]; then
  ok "No ad-hoc packages (clean)"
else
  warn "Ad-hoc packages installed (not in config, will vanish on rebuild):"
  echo "$ADHOC" | while read -r pkg; do
    echo -e "    ${YELLOW}•${NC} $pkg"
  done
  hint "Add these to home/default.nix home.packages to persist them."
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}All good.${NC}"
else
  echo -e "${YELLOW}$ISSUES issue(s) found.${NC}"
fi
