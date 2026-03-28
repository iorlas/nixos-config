# Host config for pix (OrbStack NixOS VM)
#
# OrbStack manages orbstack.nix and incus.nix on disk at /etc/nixos/.
# No corporate certs imported — clean certificate store for privacy.

{ config, lib, pkgs, modulesPath, ... }:

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
    nameservers = [ "9.9.9.9" "149.112.112.112" ];
  };

  # DNS-over-TLS via systemd-resolved
  # mkForce overrides OrbStack's `resolved.enable = false` and resolv.conf
  services.resolved = {
    enable = lib.mkForce true;
    dnsovertls = "true";
    fallbackDns = [ "1.1.1.1" "1.0.0.1" ];  # Cloudflare as fallback
    settings.Resolve = {
      DNS = [ "9.9.9.9#dns.quad9.net" "149.112.112.112#dns.quad9.net" ];
    };
  };
  environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/stub-resolv.conf";

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

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # inotify limits — Node.js file watchers need higher limits
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;
  boot.kernel.sysctl."fs.inotify.max_user_instances" = 256;

  # SSH agent forwarding — use Mac's SSH keys from inside pix
  programs.ssh.startAgent = false;  # don't start a local agent
  # The Mac's agent is forwarded via OrbStack's SSH

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
