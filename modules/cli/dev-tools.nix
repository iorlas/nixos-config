{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Node.js (runtime for Claude Code) + version manager
    nodejs_22
    fnm

    # Python
    uv

    # Build tools
    gnumake
    gcc

    # Core CLI
    git
    curl
    wget
    jq
    yq
    htop
    nano
    unzip
    tree
    lazygit
    neovim
  ];

  # VS Code Remote SSH works automatically via nix-ld (see modules/nix/nix-ld.nix).
  # Just connect from VS Code on Mac using the OrbStack SSH target.
}
