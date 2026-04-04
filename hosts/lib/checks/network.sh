#!/usr/bin/env bash
# Check: Network connectivity through exit node

check_network_exit_node() {
  local exit_node="${1:-shen}"

  echo "==> Network"
  local ts_exit
  ts_exit=$(tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
  if [ -n "$ts_exit" ]; then
    local public_ip
    public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "timeout")
    if [ "$public_ip" != "timeout" ]; then
      ok "Public IP: $public_ip (via $exit_node)"
    else
      fail "Cannot reach internet through exit node"
    fi
  else
    if curl -s --max-time 5 ifconfig.me &>/dev/null; then
      warn "Internet reachable but traffic is NOT routed through $exit_node"
    else
      fail "No internet connectivity"
    fi
  fi
}
