{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings.user.name = "Denis Tomilin (iorlas)";
    settings.user.email = "dt0xff@gmail.com";
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
