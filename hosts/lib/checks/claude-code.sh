#!/usr/bin/env bash
# Check: Claude Code — install, auth, settings, npm→native migration

_fix_claude_npm_to_native() {
  echo "  Removing npm-installed Claude Code..."
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null
  echo "  Installing native Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
}

# Default settings to ensure in settings.json
# Each key is checked and merged individually
_claude_default_settings='{
  "permissions": {"defaultMode": "bypassPermissions"},
  "skipDangerousModePermissionPrompt": true,
  "statusLine": {"type": "command", "command": "bash ~/.claude/hooks/kay-statusline.sh"}
}'

_fix_claude_settings() {
  mkdir -p "$HOME/.claude"
  local file="$HOME/.claude/settings.json"
  if [ -f "$file" ]; then
    # Merge defaults into existing settings (existing keys take precedence)
    jq --argjson defaults "$_claude_default_settings" \
      '$defaults * .' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    echo "$_claude_default_settings" | jq '.' > "$file"
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

  # Settings check (bypass permissions, statusline, etc.)
  local settings_ok=true
  if [ -f "$HOME/.claude/settings.json" ]; then
    grep -q "bypassPermissions" "$HOME/.claude/settings.json" || settings_ok=false
    grep -q "kay-statusline" "$HOME/.claude/settings.json" || settings_ok=false
    grep -q "skipDangerousModePermissionPrompt" "$HOME/.claude/settings.json" || settings_ok=false
  else
    settings_ok=false
  fi

  if $settings_ok; then
    ok "Settings configured (permissions, statusline)"
  else
    fix_or_hint "Settings missing or incomplete (permissions, statusline)" "_fix_claude_settings"
  fi
}
