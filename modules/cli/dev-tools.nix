{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Node.js (runtime for Claude Code) + version manager + package manager
    nodejs_24
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

  # VS Code Remote SSH works automatically via nix-ld (see modules/nix/nix-ld.nix).
  # Just connect from VS Code on Mac using the OrbStack SSH target.
}
