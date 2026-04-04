#!/usr/bin/env bash
# Check: Docker

check_docker() {
  echo "==> Docker"
  if command -v docker &> /dev/null; then
    if docker info &>/dev/null; then
      local docker_ver
      docker_ver=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
      ok "Docker $docker_ver"
    else
      warn "Docker not accessible"
      hint "Check: systemctl status docker (or group membership)"
    fi
  else
    warn "Docker not found on PATH"
  fi
}
