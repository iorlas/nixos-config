{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellInit = ''
      # Local scripts (bootstrap, doctor) + Claude Code (npm global)
      set -gx PATH $HOME/.local/bin $HOME/.npm-global/bin $PATH

      # fnm (Node version manager)
      fnm env --use-on-cd --shell fish | source
    '';

    interactiveShellInit = ''
      set -g fish_color_autosuggestion brblack
      set -g fish_color_command green
      set -g fish_color_error red
      set -g fish_color_param blue

      # Auto-attach tmux on interactive login (not inside tmux already)
      if status is-interactive; and not set -q TMUX
        exec tmux new-session -A -s main
      end
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
      nrs = "sudo nixos-rebuild switch --flake /mnt/mac/Users/iorlas/nixos-config#pix --impure";
    };

    functions = {
      _check_exit_node = {
        description = "Block if traffic is not routed through shen";
        body = ''
          set -l exit_id (tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
          if test -z "$exit_id"
            set_color red --bold
            echo "BLOCKED: traffic is not routed through shen."
            set_color normal
            echo "Run: doctor --fix"
            return 1
          end
        '';
      };
      claude = {
        description = "Claude Code with exit node guard";
        body = ''
          _check_exit_node; or return 1
          command claude $argv
        '';
      };
      c = {
        description = "Claude Code shortcut with exit node guard";
        body = ''
          _check_exit_node; or return 1
          command claude $argv
        '';
      };
      fish_greeting = {
        description = "Check tailscale exit node on shell start";
        body = ''
          if command -q tailscale
            set -l exit_id (tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
            if test -z "$exit_id"
              set_color -b red white --bold
              echo ""
              echo "  !! TRAFFIC IS NOT ROUTED THROUGH SHEN !!  "
              echo ""
              set_color normal
              set_color yellow
              echo "  run: doctor --fix"
              echo ""
              set_color normal
            end
          end
        '';
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
