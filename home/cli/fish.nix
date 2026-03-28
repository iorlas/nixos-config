{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellInit = ''
      # Claude Code (npm global)
      set -gx PATH $HOME/.npm-global/bin $PATH

      # fnm (Node version manager)
      fnm env --use-on-cd --shell fish | source
    '';

    interactiveShellInit = ''
      set -g fish_color_autosuggestion brblack
      set -g fish_color_command green
      set -g fish_color_error red
      set -g fish_color_param blue
    '';

    shellAbbrs = {
      g = "git";
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gd = "git diff";
      gl = "git log --oneline";
      gp = "git push";
      gs = "git status";
      dc = "docker compose";
    };

    shellAliases = {
      c = "claude";
      nrs = "sudo nixos-rebuild switch --flake /mnt/mac/Users/iorlas/nixos-config#pix";
    };

    functions = {
      fish_greeting = {
        description = "Disable greeting";
        body = "";
      };
    };

    plugins = [
      { name = "tide"; src = pkgs.fishPlugins.tide.src; }
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "done"; src = pkgs.fishPlugins.done.src; }
    ];
  };

  # Companion tools with native fish integration

  programs.zoxide = {
    enable = true;
    # replaces cd with zoxide
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [ "--height 40%" "--border" ];
  };

  programs.bat.enable = true;

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.ripgrep.enable = true;
  programs.fd.enable = true;
}
