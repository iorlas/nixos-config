#!/usr/bin/env bash
# Common doctor checks — sourced by host-specific doctors.
# Runs checks shared across all environments.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helpers
source "$LIB_DIR/checks/common.sh"

# Load check functions
source "$LIB_DIR/checks/nix.sh"
source "$LIB_DIR/checks/home-manager.sh"
source "$LIB_DIR/checks/claude-code.sh"
source "$LIB_DIR/checks/gh.sh"
source "$LIB_DIR/checks/docker.sh"
source "$LIB_DIR/checks/fish.sh"
source "$LIB_DIR/checks/ssh.sh"
source "$LIB_DIR/checks/nixos.sh"
source "$LIB_DIR/checks/tailscale.sh"
source "$LIB_DIR/checks/network.sh"
source "$LIB_DIR/checks/dns.sh"
source "$LIB_DIR/checks/home-dir.sh"

# Parse --fix flag
FIX=false
[[ "${1:-}" == "--fix" ]] && FIX=true

# Run common checks (shared across all hosts)
run_common_checks() {
  check_nix
  check_home_manager
  check_claude_code
  check_gh
  check_docker
  check_fish
  check_nix_adhoc
}
