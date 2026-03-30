{ config, pkgs, hostName, ... }:

{
  imports = [
    ./cli/git.nix
    ./cli/fish.nix
    ./cli/tmux.nix
    ./cli/direnv.nix
  ];

  home.username = "iorlas";
  home.homeDirectory = "/home/iorlas";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.file.".local/bin/bootstrap" = {
    source = ../hosts/${hostName}/bootstrap.sh;
    executable = true;
  };
  home.file.".local/bin/doctor" = {
    source = ../hosts/${hostName}/doctor.sh;
    executable = true;
  };

  home.packages = with pkgs; [
    # Node.js
    nodejs_22
    fnm
    pnpm

    # Python
    uv
    python313
    pipx

    # JavaScript runtimes
    deno

    # Build tools
    gnumake
    gcc

    # Core CLI
    git
    gh
    curl
    wget
    jq
    yq
    btop
    nano
    unzip
    tree
    lazygit
    neovim

    # Linting / security
    gitleaks
    hadolint
    yamllint
  ];
}
