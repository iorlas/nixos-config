#!/usr/bin/env bash
# Check: Tailscale with exit node verification

check_tailscale_exit_node() {
  local exit_node="${1:-shen}"

  echo "==> Tailscale"
  if ! systemctl is-active --quiet tailscaled; then
    fail "tailscaled service not running"
    return
  fi

  local ts_json ts_status
  ts_json=$(tailscale status -json 2>/dev/null)
  ts_status=$(echo "$ts_json" | jq -r .BackendState 2>/dev/null || echo "Unknown")

  case "$ts_status" in
    Running)
      local ts_ip
      ts_ip=$(tailscale ip -4 2>/dev/null || echo "no IP")
      ok "Connected ($ts_ip)"

      # Find exit node peer by ExitNode flag (IDs use different formats, can't lookup by ExitNodeStatus.ID)
      local ts_exit_id ts_exit_name ts_exit_online
      ts_exit_id=$(echo "$ts_json" | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)

      if [ -n "$ts_exit_id" ]; then
        ts_exit_name=$(echo "$ts_json" | jq -r '[.Peer | to_entries[] | select(.value.ExitNode==true)][0].value.HostName // "unknown"' 2>/dev/null)
        ts_exit_online=$(echo "$ts_json" | jq -r '[.Peer | to_entries[] | select(.value.ExitNode==true)][0].value.Online // false' 2>/dev/null)
        # Also check by DNS name (Tailscale may use machine hostname not tailnet name)
        ts_exit_dns=$(echo "$ts_json" | jq -r '[.Peer | to_entries[] | select(.value.ExitNode==true)][0].value.DNSName // ""' 2>/dev/null)

        # Match by hostname, DNS name prefix, or tailscale --exit-node name
        local matched=false
        if echo "$ts_exit_name $ts_exit_dns" | grep -qi "$exit_node"; then
          matched=true
        fi

        if $matched && [ "$ts_exit_online" = "true" ]; then
          ok "Exit node: $ts_exit_name (online)"
        elif $matched && [ "$ts_exit_online" != "true" ]; then
          fail "Exit node is $ts_exit_name but it's OFFLINE — traffic may not be routing"
          hint "Check if $exit_node is up, or switch: sudo tailscale up --exit-node=$exit_node --accept-routes"
        elif ! $matched; then
          warn "Exit node is '$ts_exit_name' (expected: $exit_node)"
          hint "Switch: sudo tailscale up --exit-node=$exit_node --accept-routes"
        fi
      else
        fix_or_hint "No exit node (expected: $exit_node)" \
          "sudo tailscale up --exit-node=$exit_node --accept-routes"
      fi
      ;;
    NeedsLogin)
      warn "Needs authentication"
      hint "Run: sudo tailscale up"
      ;;
    Stopped)
      fix_or_hint "Tailscale stopped" \
        "sudo tailscale up --exit-node=$exit_node --accept-routes"
      ;;
    *)
      fail "Unexpected state: $ts_status"
      ;;
  esac
}
