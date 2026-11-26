_:
let
  palette = import ../../config/theme/catppuccin-mocha.nix;
  tmuxAliases = {
    t = "tmux new-session -A -s dev";
  };
  # fzf backs LazyVim/shell fuzzy pickers; tmux-yank needs a system-clipboard
  # tool on Linux (macOS ships pbcopy).
  tmuxDeps =
    { lib, pkgs }:
    with pkgs;
    [ fzf ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ wl-clipboard ];
  # tmux-ssh-split is not yet in nixpkgs' tmuxPlugins, so build it from the
  # upstream tarball. It is a tmux plugin with an .rtp passthru so home-manager
  # can run-shell it like any other plugin. Upstream's pgid-based detection
  # works outside the devenv nested-pty case, which we don't support for SSH
  # splits.
  sshSplit =
    { pkgs }:
    pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
      # home-manager requires tmux plugin packages to be named tmuxplugins-*.
      pname = "tmuxplugins-ssh-split";
      version = "338bc325";
      src = pkgs.fetchurl {
        url = "https://github.com/pschmitt/tmux-ssh-split/archive/${finalAttrs.version}.tar.gz";
        hash = "sha256-LTiheZFV93hA4blyG75Bm0i/VO8H8B21YLHdrcZi9RQ=";
      };
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/tmux-plugins/tmux-ssh-split
        cp ssh-split.tmux README.md LICENSE $out/share/tmux-plugins/tmux-ssh-split/
        cp -r scripts $out/share/tmux-plugins/tmux-ssh-split/
        chmod +x $out/share/tmux-plugins/tmux-ssh-split/ssh-split.tmux \
          $out/share/tmux-plugins/tmux-ssh-split/scripts/tmux-ssh-split.sh
        runHook postInstall
      '';
      passthru.rtp = "${finalAttrs.finalPackage}/share/tmux-plugins/tmux-ssh-split/ssh-split.tmux";
      meta = {
        description = "Split tmux panes while retaining SSH connections";
        homepage = "https://github.com/pschmitt/tmux-ssh-split";
        license = pkgs.lib.licenses.gpl3;
      };
    });
  # Alternate config for sessions nested inside another tmux (`tmux -L nested`):
  # distinct prefix and no status bar. Kept as a real file so it stays lintable.
  nestedConf = builtins.readFile ../../config/tmux/nested.conf;
  tmuxCfg =
    { pkgs }:
    let
      sshSplitPkg = sshSplit { inherit pkgs; };
      smartRename = pkgs.writeShellScript "tmux-smart-rename" (
        builtins.readFile ../../config/tmux/smart-rename.sh
      );
    in
    {
      enable = true;
      # Pin tmux's default-shell to zsh so panes never fall back to the passwd
      # login shell.
      shell = "${pkgs.zsh}/bin/zsh";
      plugins = with pkgs.tmuxPlugins; [
        { plugin = vim-tmux-navigator; }
        {
          plugin = catppuccin;
          extraConfig = ''
            set -g @catppuccin_flavor "mocha"
            set -g @catppuccin_window_status_style "rounded"
            set -g @catppuccin_window_text " #W"
            set -g @catppuccin_window_current_text " #W"
            set -g @catppuccin_window_flags "none"
            set -g @catppuccin_status_left_separator ""
            set -g @catppuccin_status_right_separator ""
            set -g @catppuccin_status_connect_separator "no"
          '';
        }
        { plugin = yank; }
        { plugin = open; }
        {
          # SSH-aware splits on the same keys as plain splits: `prefix %`
          # horizontal, `prefix " vertical. The explicit binds below are the
          # fallback; the plugin's run-shell (right after) rebinds them to its
          # SSH-aware split, so the plain split stays if it ever fails to load.
          # Upstream detection (works in normal panes, no devenv workaround).
          plugin = sshSplitPkg;
          extraConfig = ''
            set -g @ssh-split-h-key "%"
            set -g @ssh-split-v-key '"'
            set -g @ssh-split-keep-cwd "true"
            set -g @ssh-split-strip-cmd "true"
            bind % split-window -h -c "#{pane_current_path}"
            bind '"' split-window -v -c "#{pane_current_path}"
          '';
        }
      ];
      extraConfig = ''
        set -g default-terminal "tmux-256color"
        set -ag terminal-overrides ",xterm-256color:RGB,xterm-ghostty:RGB"
        # Allow the kitty graphics protocol (inline images in nvim/snacks) through
        # tmux to the outer terminal (Ghostty/kitty/wezterm).
        set -g allow-passthrough on
        set -g default-command "${pkgs.zsh}/bin/zsh -l"
        set -g status-interval 5
        set -g status-right "#{E:@catppuccin_status_user}#{E:@catppuccin_status_host}#{E:@catppuccin_status_session}"
        set -g pane-border-lines simple
        set -g pane-active-border-style "fg=${palette.peach}"
        set -g renumber-windows on
        set -sg escape-time 0
        set -g history-limit 50000
        set -g display-time 4000
        set -g focus-events on
        setw -g aggressive-resize on
        set -g base-index 1
        setw -g pane-base-index 1
        # Smart window names: opencode session title first, then SSH, git repo,
        # path and command. Hooks make updates immediate; a manual rename turns
        # automatic-rename off, which pauses the script so the name sticks.
        setw -g automatic-rename on
        setw -g automatic-rename-format '#{?@smart-name,#{@smart-name},#{?pane_title,#{pane_title},#{pane_current_command}}}'
        set-hook -g -w pane-title-changed "run-shell -b '${smartRename} #{window_id}'"
        set-hook -g after-select-pane "run-shell -b '${smartRename} #{window_id}'"
        set-hook -g after-new-window "run-shell -b '${smartRename} #{window_id}'"
        set-hook -g after-split-window "run-shell -b '${smartRename} #{window_id}'"
        set -g mouse on
        setw -g mode-keys vi
        set -s set-clipboard on
        set -ga terminal-features ',*:clipboard'
        bind-key -T copy-mode-vi v send-keys -X begin-selection
        bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
        bind-key -T copy-mode-vi Enter send-keys -X copy-selection-and-cancel
        bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-and-cancel
        bind q detach-client
        bind c new-window -c "#{pane_current_path}"
        bind -n C-Tab next-window
        bind -n C-S-Tab previous-window
        # Catppuccin styles only menu-selected-style; tmux >= 3.6 defaults the
        # rest to theme-aware greys (themedarkgrey), which look off-theme.
        set -g menu-style "fg=${palette.text},bg=${palette.surface0}"
        set -g menu-border-style "fg=${palette.overlay0},bg=${palette.surface0}"
        set -g menu-selected-style "fg=${palette.crust},bg=${palette.mauve},bold"
        bind C-g display-popup -d "#{pane_current_path}" -w 80% -h 80% -E "lazygit"
        bind C-n display-popup -d "#{pane_current_path}" -w 50% -h 25% -T "New session" -E 'exec bash ${../../config/tmux/nixconf-menu.sh} new-session'
        # prefix+s names a new session and jumps to it, leaving the current
        # session running. prefix+f stays the window/session switcher.
        bind s display-popup -d "#{pane_current_path}" -w 50% -h 25% -T "New session" -E 'exec bash ${../../config/tmux/nixconf-menu.sh} new-session'
        bind C-y display-popup -d "#{pane_current_path}" -w 90% -h 90% -E "yazi"
        bind C-t display-popup -d "#{pane_current_path}" -w 75% -h 75% -E "zsh"
        bind r display-popup -w 70% -h 60% -E "${pkgs.writeShellScript "repo-switcher" ''
          exec ${../../config/tmux/repo-switcher.sh}
        ''}"
        # SSH host picker: popup -> pick a host from ~/.ssh/config -> attach a
        # tmux session on it (persistent) or a plain shell.
        bind h display-popup -w 70% -h 60% -E "${pkgs.writeShellScript "ssh-switcher" (builtins.readFile ../../config/tmux/ssh-switcher.sh)}"
        # Session/window switcher on tv (television), same pattern as r. The
        # script content is inlined via readFile so the store wrapper is
        # executable regardless of the git mode of the source file.
        bind f display-popup -w 70% -h 60% -E "${pkgs.writeShellScript "session-switcher" (builtins.readFile ../../config/tmux/session-switcher.sh)}"
        # Keybinding reference: prefix+? dumps every binding, paged.
        bind ? display-popup -w 90% -h 90% -E "${pkgs.writeShellScript "list-keys" ''
          tmux list-keys | ${pkgs.less}/bin/less -R
        ''}"
        bind d display-menu -T "#[align=centre]Nixconf" -x C -y C \
          "New session" n "display-popup -d '#{pane_current_path}' -E 'exec bash ${../../config/tmux/nixconf-menu.sh} new-session'" \
          "Switch repo"  r "display-popup -w 70% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} repo-switch'" \
          "Sessions"     s "display-popup -d '#{pane_current_path}' -E 'exec bash ${../../config/tmux/nixconf-menu.sh} sessions'" \
          "Lazygit"      l "display-popup -d '#{pane_current_path}' -w 80% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} lazygit'" \
          "Yazi"         y "display-popup -d '#{pane_current_path}' -w 80% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} yazi'" \
          "SSH host"     h "display-popup -w 70% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} ssh'"
        set -g set-titles on
        set -g set-titles-string "#S - #W"
        set -g status-position top
        set -g status-left-length 100
        set -g status-right-length 100
        set -g status-left "#{E:@catppuccin_status_application}"
      '';
    };
in
{
  nixconf.modules.nixos.tmux =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.tmux.enable = lib.mkEnableOption "Tmux";
      config = lib.mkIf config.modules.tmux.enable {
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (_: {
          programs.tmux = tmuxCfg { inherit pkgs; };
          xdg.configFile."tmux/nested.conf".text = nestedConf;
          programs.zsh.shellAliases = tmuxAliases;
          home.packages = tmuxDeps { inherit lib pkgs; };
        });
      };
    };

  nixconf.modules.homeManager.tmux =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.tmux.enable = lib.mkEnableOption "Tmux";
      config = lib.mkIf config.modules.tmux.enable {
        programs.tmux = tmuxCfg { inherit pkgs; };
        xdg.configFile."tmux/nested.conf".text = nestedConf;
        programs.zsh.shellAliases = tmuxAliases;
        home.packages = tmuxDeps { inherit lib pkgs; };
      };
    };
}
