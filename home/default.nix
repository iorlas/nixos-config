{ config, pkgs, ... }:

{
  imports = [
    ./cli/git.nix
    ./cli/fish.nix
    ./cli/direnv.nix
  ];

  home.username = "iorlas";
  home.homeDirectory = "/home/iorlas";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
