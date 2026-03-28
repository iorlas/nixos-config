# System-level fish — required for vendor completions from nixpkgs.
# User-level config (plugins, abbreviations) lives in home/cli/fish.nix.
{ config, pkgs, ... }:

{
  programs.fish.enable = true;
  users.users.iorlas.shell = pkgs.fish;
  documentation.man.generateCaches = false;
}
