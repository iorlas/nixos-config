#!/usr/bin/env bash
# Health check for pix. Read-only, never changes state.
# Run anytime: `doctor`

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
ISSUES=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}→${NC} $1"; ISSUES=$((ISSUES + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ISSUES=$((ISSUES + 1)); }

# ─── NixOS ─────────────────────────────────────────────────────────────────────

echo "==> NixOS"
if [ -L /run/current-system ]; then
  NIXOS_VER=$(nixos-version 2>/dev/null || echo "unknown")
  ok "NixOS $NIXOS_VER"
else
  fail "Not running NixOS"
fi

# ─── Claude Code ───────────────────────────────────────────────────────────────

echo "==> Claude Code"
export PATH="$HOME/.npm-global/bin:$PATH"
if command -v claude &> /dev/null; then
  CLAUDE_VER=$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ok "Installed ($CLAUDE_VER)"

  LATEST=$(npm view @anthropic-ai/claude-code version 2>/dev/null || echo "")
  if [ -n "$LATEST" ] && [ "$CLAUDE_VER" != "$LATEST" ]; then
    warn "Update available: $CLAUDE_VER → $LATEST. Run: npm install -g @anthropic-ai/claude-code"
  fi
else
  fail "Not installed. Run: bootstrap"
fi

if [ -d "$HOME/.claude" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
  ok "Authenticated"
else
  warn "Not authenticated. Run: claude"
fi

# ─── Tailscale ─────────────────────────────────────────────────────────────────

echo "==> Tailscale"
if ! systemctl is-active --quiet tailscaled; then
  fail "tailscaled service not running"
else
  TS_STATUS=$(tailscale status -json 2>/dev/null | jq -r .BackendState 2>/dev/null || echo "Unknown")
  case "$TS_STATUS" in
    Running)
      TS_IP=$(tailscale ip -4 2>/dev/null || echo "no IP")
      ok "Connected ($TS_IP)"

      # Check exit node — should be shen (100.65.108.29)
      EXPECTED_EXIT="shen"
      EXPECTED_EXIT_IP="100.65.108.29"
      TS_EXIT=$(tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
      if [ -n "$TS_EXIT" ]; then
        TS_EXIT_NAME=$(tailscale status 2>/dev/null | grep -E "exit node" | awk '{print $2}' || echo "unknown")
        ok "Exit node active ($TS_EXIT_NAME)"
      else
        warn "No exit node. Run: sudo tailscale up --exit-node=$EXPECTED_EXIT_IP --accept-routes"
      fi
      ;;
    NeedsLogin)
      warn "Needs auth. Run: sudo tailscale up"
      ;;
    Stopped)
      warn "Stopped. Run: sudo tailscale up"
      ;;
    *)
      fail "Unexpected state: $TS_STATUS"
      ;;
  esac
fi

# ─── Docker ────────────────────────────────────────────────────────────────────

echo "==> Docker"
if systemctl is-active --quiet docker; then
  ok "Docker $(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
else
  fail "Not running. Run: sudo systemctl start docker"
fi

# ─── Network ───────────────────────────────────────────────────────────────────

echo "==> Network"
TS_EXIT=$(tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
if [ -n "$TS_EXIT" ]; then
  PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "timeout")
  if [ "$PUBLIC_IP" != "timeout" ]; then
    ok "Public IP: $PUBLIC_IP (via shen exit node)"
  else
    fail "Cannot reach internet through exit node"
  fi
else
  if curl -s --max-time 5 ifconfig.me &>/dev/null; then
    warn "Internet reachable but traffic is NOT routed through shen"
  else
    fail "No internet connectivity"
  fi
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}All good.${NC}"
else
  echo -e "${YELLOW}$ISSUES issue(s) found.${NC}"
fi
