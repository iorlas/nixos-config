#!/usr/bin/env bash
# Health check for pix (OrbStack NixOS VM).
# Use --fix to auto-fix what can be fixed.
set -uo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/doctor-common.sh" "$@"

# ─── Common checks ────────────────────────────────────────────────────────────

run_common_checks

# ─── Pix-specific checks ─────────────────────────────────────────────────────

check_nixos
check_ssh_agent
check_tailscale_exit_node "shen"
check_network_exit_node "shen"
check_dns_quad9

# ─── Summary ──────────────────────────────────────────────────────────────────

doctor_summary

# ─── Host-side checklist (always shown) ────────────────────────────────────────

echo ""
echo -e "${DIM}Host-side (macOS) checklist:${NC}"
echo -e "${DIM}  iTerm2 > Settings > General > tmux:${NC}"
echo -e "${DIM}    • \"Automatically bury the tmux client session\" → ON${NC}"
echo -e "${DIM}    • \"When attaching, restore windows as\" → your preference${NC}"
echo -e "${DIM}  iTerm2 > Settings > Profiles > Terminal:${NC}"
echo -e "${DIM}    • \"Notification center\" or \"Bounce dock icon\" → ON${NC}"
echo -e "${DIM}    • (for command completion alerts from Claude Code)${NC}"
