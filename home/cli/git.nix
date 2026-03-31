{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Denis Tomilin (iorlas)";
    userEmail = "dt0xff@gmail.com";
    delta.enable = true;
  };
}
