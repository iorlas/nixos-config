{ config, pkgs, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Nix DX tools
  programs.nix-index.enable = true;  # nix-locate to find packages by file

  environment.systemPackages = with pkgs; [
    comma   # , cowsay — run any nix package without installing
    nh      # nicer nixos-rebuild with diffs between generations
  ];
}
