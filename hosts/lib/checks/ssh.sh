#!/usr/bin/env bash
# Check: SSH

check_ssh_keys() {
  echo "==> SSH Keys"
  if [ -f "$HOME/.ssh/authorized_keys" ]; then
    local key_count
    key_count=$(wc -l < "$HOME/.ssh/authorized_keys")
    ok "$key_count authorized key(s)"
  else
    warn "No authorized_keys"
    hint "Run: curl -fsSL https://github.com/iorlas.keys > ~/.ssh/authorized_keys"
  fi
}

check_ssh_agent() {
  echo "==> SSH Agent"
  if ssh-add -l &>/dev/null; then
    local key_count
    key_count=$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
    ok "$key_count key(s) available"
  else
    warn "No SSH keys available"
    hint "OrbStack should forward your Mac's SSH agent automatically."
    hint "If this fails, check on Mac: ssh-add -l"
  fi
}
