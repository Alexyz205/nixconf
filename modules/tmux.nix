{lib, ...}: let
  tmuxCfg = {
    enable = true;
    extraConfig = ''
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ",xterm-256color:RGB,xterm-ghostty:RGB"
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
      bind h split-window -h
      bind | split-window -h
      bind v split-window -v
      bind - split-window -v
      bind -n C-Tab next-window
      bind -n C-S-Tab previous-window
      bind C-g display-popup -d "#{pane_current_path}" -w 80% -h 80% -E "lazygit"
      bind C-n display-popup -E 'bash -i -c "read -p \"Session name: \" name; tmux new-session -d -s $name && tmux switch-client -t $name"'
      bind C-j display-popup -E "tmux choose-session"
      bind C-y display-popup -d "#{pane_current_path}" -w 90% -h 90% -E "yazi"
      bind C-t display-popup -d "#{pane_current_path}" -w 75% -h 75% -E "zsh"
      bind d display-menu -T "#[align=centre]Dotfiles" -x C -y C \
        ".zshrc"      z  "display-popup -E 'nvim ~/.zshrc'" \
        ".tmux.conf"  t  "display-popup -E 'nvim ~/.tmux.conf'" \
        "yazi"        y  "display-popup -E 'yazi'" \
        "Exit"        q  ""
      set -g @plugin 'tmux-plugins/tpm'
      set -g @plugin 'catppuccin/tmux'
      set -g @plugin 'christoomey/vim-tmux-navigator'
      set -g @plugin 'tmux-plugins/tmux-resurrect'
      set -g @plugin 'tmux-plugins/tmux-continuum'
      set -g @continuum-restore 'on'
      set -g @continuum-boot 'off'
      set -g @catppuccin_flavor "mocha"
      set -g set-titles on
      set -g set-titles-string "#S - #W"
      set -g @catppuccin_window_status_style "rounded"
      set -g @catppuccin_window_default_text "#W"
      set -g @catppuccin_window_current_text "#W"
      set -g @catppuccin_status_left_separator ""
      set -g @catppuccin_status_right_separator ""
      set -g @catppuccin_status_connect_separator "no"
      run '~/.tmux/plugins/tpm/tpm'
      set -g status-position top
      set -g status-left-length 100
      set -g status-right-length 100
      set -g status-left "#{E:@catppuccin_status_application}"
      set -g status-right "#{E:@catppuccin_status_user}#{E:@catppuccin_status_host}#{E:@catppuccin_status_session}"
    '';
  };
in {
  flake.modules.nixos.tmux = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.tmux.enable = lib.mkEnableOption "Tmux";
    config = lib.mkIf config.modules.tmux.enable {
      home-manager.users.${config.modules.users.userName}.programs.tmux = tmuxCfg;
    };
  };

  flake.modules.homeManager.tmux = {...}: {
    programs.tmux = tmuxCfg;
  };
}
