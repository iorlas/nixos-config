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

      local ts_exit_id ts_exit_name ts_exit_online
      ts_exit_id=$(echo "$ts_json" | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)

      if [ -n "$ts_exit_id" ]; then
        ts_exit_name=$(echo "$ts_json" | jq -r --arg id "$ts_exit_id" '.Peer[$id].HostName // "unknown"' 2>/dev/null)
        ts_exit_online=$(echo "$ts_json" | jq -r --arg id "$ts_exit_id" '.Peer[$id].Online // false' 2>/dev/null)

        if [ "$ts_exit_name" = "$exit_node" ] && [ "$ts_exit_online" = "true" ]; then
          ok "Exit node: $ts_exit_name (online)"
        elif [ "$ts_exit_name" = "$exit_node" ] && [ "$ts_exit_online" != "true" ]; then
          fail "Exit node is $ts_exit_name but it's OFFLINE — traffic may not be routing"
          hint "Check if $exit_node is up, or switch: sudo tailscale up --exit-node=$exit_node --accept-routes"
        elif [ "$ts_exit_name" != "$exit_node" ]; then
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
