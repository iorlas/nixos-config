{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings.user.name = "Denis Tomilin (iorlas)";
    settings.user.email = "dt0xff@gmail.com";
    settings.credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    settings.protocol.https.host = "github.com";
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
