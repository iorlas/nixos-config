#!/usr/bin/env bash
# Check: Claude Code — install, auth, statusline, npm→native migration

_fix_claude_npm_to_native() {
  echo "  Removing npm-installed Claude Code..."
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null
  echo "  Installing native Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
}

_fix_claude_statusline() {
  mkdir -p "$HOME/.claude"
  local file="$HOME/.claude/settings.json"
  if [ -f "$file" ]; then
    jq '.statusLine = {"type": "command", "command": "bash ~/.claude/hooks/kay-statusline.sh"}' \
      "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    echo '{"statusLine": {"type": "command", "command": "bash ~/.claude/hooks/kay-statusline.sh"}}' > "$file"
  fi
}

check_claude_code() {
  echo "==> Claude Code"
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.nix-profile/bin:$PATH"

  if command -v claude &> /dev/null; then
    local claude_ver claude_path
    claude_ver=$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    claude_path=$(which claude)
    ok "Installed ($claude_ver)"

    # Check if using npm install (should migrate to native)
    if echo "$claude_path" | grep -q "npm-global"; then
      fix_or_hint "Using npm-installed Claude Code (should migrate to native installer)" \
        "_fix_claude_npm_to_native"
    fi
  else
    fail "Not installed"
    hint "Run: curl -fsSL https://claude.ai/install.sh | bash"
  fi

  # Auth check
  if [ -d "$HOME/.claude" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
    ok "Authenticated"
  else
    warn "Not authenticated"
    hint "Run: claude (first-run opens browser auth)"
  fi

  # Statusline check
  if [ -f "$HOME/.claude/settings.json" ] && grep -q "kay-statusline" "$HOME/.claude/settings.json"; then
    ok "Statusline configured"
  else
    fix_or_hint "Statusline not configured in settings.json" "_fix_claude_statusline"
  fi
}
