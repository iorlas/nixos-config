#!/usr/bin/env bash
# Health check for pix (OrbStack NixOS VM). By default read-only.
# Use --fix to auto-fix what can be fixed.
#
# Usage:
#   doctor        # check only
#   doctor --fix  # check + fix

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
    echo -ne "     Fix now? [y/N] "
    read -r REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      echo -e "     Running: $2"
      if eval "$2"; then
        ok "Fixed"
      else
        fail "Fix failed"
      fi
    else
      echo -e "     Skipped. Manual: $2"
    fi
  fi
}

fix_claude_statusline() {
  mkdir -p "$HOME/.claude"
  local file="$HOME/.claude/settings.json"
  if [ -f "$file" ]; then
    jq '.statusLine = {"type": "command", "command": "bash ~/.claude/hooks/kay-statusline.sh"}' \
      "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    echo '{"statusLine": {"type": "command", "command": "bash ~/.claude/hooks/kay-statusline.sh"}}' > "$file"
  fi
}

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
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  CLAUDE_VER=$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ok "Installed ($CLAUDE_VER)"
else
  fail "Not installed"
  hint "Run: curl -fsSL https://claude.ai/install.sh | bash"
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
  fix_or_hint "Statusline not configured in settings.json" "fix_claude_statusline"
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

# ─── SSH Agent ────────────────────────────────────────────────────────────────

echo "==> SSH Agent"
if ssh-add -l &>/dev/null; then
  KEY_COUNT=$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
  ok "$KEY_COUNT key(s) available"
else
  warn "No SSH keys available"
  hint "OrbStack should forward your Mac's SSH agent automatically."
  hint "If this fails, check on Mac: ssh-add -l"
fi

# ─── Tailscale ─────────────────────────────────────────────────────────────────

echo "==> Tailscale"
EXIT_NODE="shen"

if ! systemctl is-active --quiet tailscaled; then
  fail "tailscaled service not running"
else
  TS_STATUS=$(tailscale status -json 2>/dev/null | jq -r .BackendState 2>/dev/null || echo "Unknown")
  case "$TS_STATUS" in
    Running)
      TS_IP=$(tailscale ip -4 2>/dev/null || echo "no IP")
      ok "Connected ($TS_IP)"

      TS_EXIT=$(tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
      if [ -n "$TS_EXIT" ]; then
        TS_EXIT_NAME=$(tailscale status 2>/dev/null | grep -E "exit node" | awk '{print $2}' || echo "unknown")
        ok "Exit node active ($TS_EXIT_NAME)"
      else
        fix_or_hint "No exit node (expected: $EXIT_NODE)" \
          "sudo tailscale up --exit-node=$EXIT_NODE --accept-routes"
      fi
      ;;
    NeedsLogin)
      warn "Needs authentication"
      hint "Run: sudo tailscale up"
      ;;
    Stopped)
      fix_or_hint "Tailscale stopped" \
        "sudo tailscale up --exit-node=$EXIT_NODE --accept-routes"
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
  fix_or_hint "Docker not running" \
    "sudo systemctl start docker"
fi

# ─── Network ───────────────────────────────────────────────────────────────────

echo "==> Network"
TS_EXIT=$(tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
if [ -n "$TS_EXIT" ]; then
  PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "timeout")
  if [ "$PUBLIC_IP" != "timeout" ]; then
    ok "Public IP: $PUBLIC_IP (via $EXIT_NODE)"
  else
    fail "Cannot reach internet through exit node"
  fi
else
  if curl -s --max-time 5 ifconfig.me &>/dev/null; then
    warn "Internet reachable but traffic is NOT routed through $EXIT_NODE"
  else
    fail "No internet connectivity"
  fi
fi

# ─── DNS ──────────────────────────────────────────────────────────────────────

echo "==> DNS"
if systemctl is-active --quiet systemd-resolved; then
  DNS_SERVERS=$(resolvectl status 2>/dev/null | grep "DNS Servers" | head -1 || echo "")
  if echo "$DNS_SERVERS" | grep -q "9.9.9.9"; then
    ok "DNS-over-TLS via Quad9"
  else
    warn "DNS not using Quad9: $DNS_SERVERS"
    hint "This should be configured by NixOS. Run: bootstrap"
  fi
else
  warn "systemd-resolved not running — DNS may leak through corporate resolver"
  hint "This should be configured by NixOS. Run: bootstrap"
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}All good.${NC}"
else
  echo -e "${YELLOW}$ISSUES issue(s) found.${NC}"
  if ! $FIX; then
    echo -e "Run ${YELLOW}doctor --fix${NC} to auto-fix what can be fixed."
  fi
fi

# ─── Host-side checklist (always shown) ────────────────────────────────────────

echo ""
echo -e "${DIM}Host-side (macOS) checklist:${NC}"
echo -e "${DIM}  iTerm2 > Settings > General > tmux:${NC}"
echo -e "${DIM}    • \"Automatically bury the tmux client session\" → ON${NC}"
echo -e "${DIM}    • \"When attaching, restore windows as\" → your preference${NC}"
echo -e "${DIM}  iTerm2 > Settings > Profiles > Terminal:${NC}"
echo -e "${DIM}    • \"Notification center\" or \"Bounce dock icon\" → ON${NC}"
echo -e "${DIM}    • (for command completion alerts from Claude Code)${NC}"
