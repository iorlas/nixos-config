#!/usr/bin/env bash
# Health check for fox (bare user on shen).
# Use --fix to auto-fix what can be fixed.
set -uo pipefail

source "$HOME/.local/lib/doctor-checks/doctor-common.sh" "$@"

# ─── Common checks ────────────────────────────────────────────────────────────

run_common_checks

# ─── Fox-specific checks ─────────────────────────────────────────────────────

check_ssh_keys
check_fish_trampoline
check_home_permissions

# ─── Summary ──────────────────────────────────────────────────────────────────

doctor_summary
