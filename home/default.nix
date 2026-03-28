{ config, pkgs, ... }:

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

  # Put bootstrap/doctor on PATH as real scripts (work in any shell, non-interactive too)
  home.file.".local/bin/bootstrap" = {
    source = ../bootstrap.sh;
    executable = true;
  };
  home.file.".local/bin/doctor" = {
    source = ../doctor.sh;
    executable = true;
  };
}
