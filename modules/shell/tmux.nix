{ lib, ... }:
let
  tmuxAliases = {
    t = "tmux new-session -A -s dev";
  };
  tmuxCfg = { pkgs }: {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      { plugin = vim-tmux-navigator; }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-processes 'ssh:no,node:no'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'off'
        '';
      }
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_default_text "#W"
          set -g @catppuccin_window_current_text "#W"
          set -g @catppuccin_status_left_separator ""
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_connect_separator "no"
          set -g @catppuccin_pane_active_border_style "fg=#{@thm_peach}"
        '';
      }
    ];
    extraConfig = ''
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ",xterm-256color:RGB,xterm-ghostty:RGB"
      # Allow the kitty graphics protocol (inline images in nvim/snacks) through
      # tmux to the outer terminal (Ghostty/kitty/wezterm).
      set -g allow-passthrough on
      set -g default-shell "${pkgs.zsh}/bin/zsh"
      set -g default-command "${pkgs.zsh}/bin/zsh -l"
      set -g pane-border-lines simple
      set -g renumber-windows on
      set -sg escape-time 0
      set -g history-limit 50000
      set -g display-time 4000
      set -g status-interval 5
      set -g focus-events on
      setw -g aggressive-resize on
      set -g base-index 1
      setw -g pane-base-index 1
      set -g mouse on
      setw -g mode-keys vi
      set -s set-clipboard on
      set -ga terminal-features ',*:clipboard'
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi Enter send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-and-cancel
      bind f resize-pane -Z
      bind q detach-client
      bind e choose-window -Z
      bind % split-window -h -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      bind -n C-Tab next-window
      bind -n C-S-Tab previous-window
      bind C-g display-popup -d "#{pane_current_path}" -w 80% -h 80% -E "lazygit"
      bind C-n display-popup -d "#{pane_current_path}" -w 50% -h 25% -T "New session" -E 'exec bash ${../../config/tmux/nixconf-menu.sh} new-session'
      bind C-y display-popup -d "#{pane_current_path}" -w 90% -h 90% -E "yazi"
      bind C-t display-popup -d "#{pane_current_path}" -w 75% -h 75% -E "zsh"
      bind R display-popup -w 70% -h 60% -E "${pkgs.writeShellScript "repo-switcher" ''
        exec ${../../config/tmux/repo-switcher.sh}
      ''}"
      bind d display-menu -T "#[align=centre]Nixconf" -x C -y C \
        "New session" n "display-popup -d '#{pane_current_path}' -E 'exec bash ${../../config/tmux/nixconf-menu.sh} new-session'" \
        "Switch repo"  r "display-popup -w 70% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} repo-switch'" \
        "Sessions"     s "display-popup -d '#{pane_current_path}' -E 'exec bash ${../../config/tmux/nixconf-menu.sh} sessions'" \
        "Lazygit"      l "display-popup -d '#{pane_current_path}' -w 80% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} lazygit'" \
        "Yazi"         y "display-popup -d '#{pane_current_path}' -w 80% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} yazi'" \
        "Exit"         q ""
      set -g set-titles on
      set -g set-titles-string "#S - #W"
      set -g status-position top
      set -g status-left-length 100
      set -g status-right-length 100
      set -g status-left "#{E:@catppuccin_status_application}"
      set -g status-right "#{E:@catppuccin_status_user}#{E:@catppuccin_status_host}#{E:@catppuccin_status_session}"
    '';
  };
in
{
  flake.modules.nixos.tmux =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.tmux.enable = lib.mkEnableOption "Tmux";
      config = lib.mkIf config.modules.tmux.enable {
        home-manager.users.${config.modules.users.userName} = {
          programs.tmux = tmuxCfg { inherit pkgs; };
          programs.zsh.shellAliases = tmuxAliases;
        };
      };
    };

  flake.modules.homeManager.tmux =
    {
      pkgs,
      ...
    }:
    {
      programs.tmux = tmuxCfg { inherit pkgs; };
      programs.zsh.shellAliases = tmuxAliases;
    };
}
