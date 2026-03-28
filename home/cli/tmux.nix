{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;

    shell = "${pkgs.fish}/bin/fish";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    terminal = "tmux-256color";
    sensibleOnTop = true;
    clock24 = true;
    focusEvents = true;

    plugins = with pkgs.tmuxPlugins; [
      yank
      {
        plugin = better-mouse-mode;
        extraConfig = ''
          set -g @emulate-scroll-for-no-mouse-alternate-buffer "on"
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim "session"
          set -g @resurrect-capture-pane-contents "on"
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore "on"
          set -g @continuum-save-interval "10"
        '';
      }
    ];

    extraConfig = ''
      # True color (iTerm2)
      set -as terminal-overrides ",xterm-256color:RGB"

      # OSC 52 clipboard (works over SSH → local clipboard)
      set -s set-clipboard on

      # Window behavior
      set -g renumber-windows on

      # Window/terminal title — shows "session-name @ pix"
      set -g set-titles on
      set -g set-titles-string "#S @ pix"
      set -g automatic-rename on

      # Don't kill sessions — detach instead of exit on window close
      set -g detach-on-destroy on
      set -g destroy-unattached off
      set -g exit-unattached off

      # Splits/windows inherit current directory
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Vi copy mode
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel

      # Pane navigation (no prefix)
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Window navigation (no prefix)
      bind -n S-Left previous-window
      bind -n S-Right next-window

      # Pane resizing
      bind -n M-S-Left resize-pane -L 2
      bind -n M-S-Right resize-pane -R 2
      bind -n M-S-Up resize-pane -U 2
      bind -n M-S-Down resize-pane -D 2

      # Minimal status bar
      set -g status-position top
      set -g status-style "bg=default,fg=default"
      set -g status-left "#[bold] #S "
      set -g status-left-length 20
      set -g status-right ""
      set -g window-status-format "#[dim] #I:#W "
      set -g window-status-current-format "#[bold] #I:#W "
      set -g window-status-separator ""
      set -g pane-border-style "fg=colour240"
      set -g pane-active-border-style "fg=colour4"
    '';
  };
}
