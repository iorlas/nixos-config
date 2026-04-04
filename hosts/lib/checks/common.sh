#!/usr/bin/env bash
# Shared helpers for doctor checks

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
  # $1 = hint message, $2 = fix command (string or function name)
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

doctor_summary() {
  echo ""
  if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}All good.${NC}"
  else
    echo -e "${YELLOW}$ISSUES issue(s) found.${NC}"
    if ! $FIX; then
      echo -e "Run ${YELLOW}doctor --fix${NC} to auto-fix what can be fixed."
    fi
  fi
}
