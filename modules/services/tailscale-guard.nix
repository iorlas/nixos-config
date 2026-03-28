# Ensures tailscale exit node (shen) stays connected.
# Checks every 5 minutes, auto-reconnects if dropped.
{ config, pkgs, ... }:

let
  exitNode = "shen";
in
{
  systemd.services.tailscale-guard = {
    description = "Ensure Tailscale exit node (${exitNode}) is active";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "tailscale-guard" ''
        export PATH="${pkgs.tailscale}/bin:${pkgs.jq}/bin:$PATH"

        STATUS=$(tailscale status -json 2>/dev/null | jq -r .BackendState 2>/dev/null || echo "Unknown")

        if [ "$STATUS" != "Running" ]; then
          echo "Tailscale not running (state: $STATUS), skipping"
          exit 0
        fi

        EXIT_ID=$(tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)

        if [ -z "$EXIT_ID" ]; then
          echo "No exit node active, reconnecting to ${exitNode}..."
          tailscale up --exit-node=${exitNode} --accept-routes
          echo "Reconnected to ${exitNode}"
        fi
      '';
    };
  };

  systemd.timers.tailscale-guard = {
    description = "Check Tailscale exit node every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };
}
