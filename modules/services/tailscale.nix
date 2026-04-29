{ config, pkgs, ... }:

{
  services.tailscale.enable = true;

  systemd.services.tailscaled.environment.TS_DEBUG_ALWAYS_USE_DERP = "1";

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
