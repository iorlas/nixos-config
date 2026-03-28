# Host config for pix (OrbStack NixOS VM)
#
# OrbStack manages orbstack.nix and incus.nix on disk at /etc/nixos/.
# The bootstrap script extracts certificates into /etc/nixos/certs.nix.

{ config, pkgs, modulesPath, ... }:

{
  imports = [
    # OrbStack-managed (live on the VM, not in this repo)
    /etc/nixos/orbstack.nix
    /etc/nixos/incus.nix
    "${modulesPath}/virtualisation/lxc-container.nix"

    # System modules
    ../../modules/nix/settings.nix
    ../../modules/nix/nix-ld.nix
    ../../modules/services/docker.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/tailscale-guard.nix
    ../../modules/shell/fish.nix
    ../../modules/cli/dev-tools.nix
  ];

  # User (must match OrbStack's UID mapping)
  users.users.iorlas = {
    uid = 501;
    extraGroups = [ "wheel" "orbstack" "docker" ];
    isSystemUser = true;
    group = "users";
    createHome = true;
    home = "/home/iorlas";
    homeMode = "700";
    useDefaultShell = true;
  };

  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = false;

  time.timeZone = "Europe/Istanbul";

  # Networking (OrbStack-specific)
  networking = {
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
  };

  systemd.network = {
    enable = true;
    networks."50-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
