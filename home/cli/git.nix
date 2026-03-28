{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Denis Abdullin";
    userEmail = "iorlas@gmail.com";
    delta.enable = true;
  };
}
