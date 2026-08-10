{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.tmux = {
    enable = true;

    extraConfig = ''
      # =============================
      # TMUX Configuration
      # =============================

      # --- Basic Settings ---
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ",xterm-256color:RGB,xterm-ghostty:RGB"  # true color support
      set -g pane-border-lines simple
      set -g renumber-windows on  # keep numbering sequential

      # --- Performance & Behavior ---
      set -sg escape-time 0
      set -g history-limit 50000
      set -g display-time 4000
      set -g status-interval 5
      set -g focus-events on
      setw -g aggressive-resize on

      # --- Indexing ---
      set -g base-index 1
      setw -g pane-base-index 1

      # --- Mouse & VI Mode ---
      set -g mouse on
      setw -g mode-keys vi

      # --- Clipboard Integration (OSC 52 for DevPod/SSH/DevContainer) ---
      # Uses tmux built-in OSC 52 support (requires tmux 3.2+)
      # Works over SSH, containers, and locally (no X11 needed)
      set -s set-clipboard on
      set -ga terminal-features ',*:clipboard'
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi Enter send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-and-cancel

      # --- General Keybindings ---
      bind f resize-pane -Z  # toggle pane zoom
      bind q detach-client   # detach from session
      bind e choose-window -Z  # choose window with zoom

      # --- Pane Splitting ---
      bind h split-window -h  # horizontal split
      bind | split-window -h  # horizontal split (alternative)
      bind v split-window -v  # vertical split
      bind - split-window -v  # vertical split (alternative)

      # --- Window Navigation ---
      bind -n C-Tab next-window      # next window
      bind -n C-S-Tab previous-window  # previous window

      # =============================
      # POPUP WINDOWS
      # =============================

      # --- Git Management ---
      bind C-l display-popup \
        -d "#{pane_current_path}" \
        -w 80% \
        -h 80% \
        -E "lazygit"

      # --- Session Management ---
      bind C-n display-popup -E 'bash -i -c "read -p \"Session name: \" name; tmux new-session -d -s \$name && tmux switch-client -t \$name"'
      bind C-j display-popup -E "tmux choose-session"

      # --- File Management ---
      bind C-y display-popup \
        -d "#{pane_current_path}" \
        -w 90% \
        -h 90% \
        -E "yazi"

      # --- Configuration Editing ---
      bind C-z display-popup \
        -w 80% \
        -h 80% \
        -E 'nvim ~/.zshrc'

      # --- Terminal Popup ---
      bind C-t display-popup \
        -d "#{pane_current_path}" \
        -w 75% \
        -h 75% \
        -E "zsh"

      # =============================
      # DISPLAY MENU
      # =============================

      # --- Quick Access Menu ---
      bind d display-menu -T "#[align=centre]Dotfiles" -x C -y C \
        ".zshrc"      z  "display-popup -E 'nvim ~/.zshrc'" \
        ".tmux.conf"  t  "display-popup -E 'nvim ~/.tmux.conf'" \
        "yazi"        y  "display-popup -E 'yazi'" \
        "Exit"        q  ""

      # =============================
      # PLUGINS
      # =============================

      # --- Plugin Manager ---
      set -g @plugin 'tmux-plugins/tpm'

      # --- Theme ---
      set -g @plugin 'catppuccin/tmux'

      # --- Navigation ---
      set -g @plugin 'christoomey/vim-tmux-navigator'

      # --- Session Management ---
      set -g @plugin 'tmux-plugins/tmux-resurrect'
      set -g @plugin 'tmux-plugins/tmux-continuum'

      # --- Plugin Configuration ---
      # Automatic session restore
      set -g @continuum-restore 'on'
      set -g @continuum-boot 'off'

      # Initialize TMUX plugin manager (keep this line at the very bottom)
      run '~/.tmux/plugins/tpm/tpm'

    '';
  };
}
