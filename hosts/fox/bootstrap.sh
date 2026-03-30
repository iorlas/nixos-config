#!/usr/bin/env bash
# First-run setup for fox (Docker dev container). Most tools baked into image.
set -euo pipefail

echo "==> Running doctor to check environment..."
doctor

echo ""
echo "==> First-time setup checklist:"
echo "  1. gh auth login     (GitHub CLI authentication)"
echo "  2. claude             (Claude Code first-run auth)"
echo ""
echo "Run these commands manually, then 'doctor' again to verify."
