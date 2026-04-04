#!/usr/bin/env bash
# Check: Network connectivity through exit node

# Known public IPs of exit nodes
declare -A EXIT_NODE_IPS=(
  ["shen"]="38.242.156.243"
)

check_network_exit_node() {
  local exit_node="${1:-shen}"
  local expected_ip="${EXIT_NODE_IPS[$exit_node]:-}"

  echo "==> Network"
  local ts_exit
  ts_exit=$(tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
  if [ -n "$ts_exit" ]; then
    local public_ip
    public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "timeout")
    if [ "$public_ip" = "timeout" ]; then
      fail "Cannot reach internet through exit node"
    elif [ -n "$expected_ip" ] && [ "$public_ip" = "$expected_ip" ]; then
      ok "Public IP: $public_ip (verified: traffic routes through $exit_node)"
    elif [ -n "$expected_ip" ] && [ "$public_ip" != "$expected_ip" ]; then
      fail "Public IP is $public_ip but $exit_node should be $expected_ip — traffic NOT routing through $exit_node!"
      hint "Check: sudo tailscale up --exit-node=$exit_node --accept-routes"
    else
      ok "Public IP: $public_ip (via $exit_node, IP not verified)"
    fi
  else
    if curl -s --max-time 5 ifconfig.me &>/dev/null; then
      warn "Internet reachable but traffic is NOT routed through $exit_node"
    else
      fail "No internet connectivity"
    fi
  fi
}
