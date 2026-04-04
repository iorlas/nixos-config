{ config, pkgs, ... }:

{
  # User packages are managed by home-manager in home/default.nix
  # (shared between pix and fox).
  #
  # VS Code Remote SSH works automatically via nix-ld (see modules/nix/nix-ld.nix).
  # Just connect from VS Code on Mac using the OrbStack SSH target.
}
