_:
let
  tmuxAliases = {
    t = "tmux new-session -A -s dev";
  };
  # Plugin dependencies that must be on $PATH inside tmux: tmux-yank needs a
  # system-clipboard tool on Linux (macOS ships pbcopy). jq is used by the
  # opencode bridge to read opencode-session-status state files. The fzf
  # switcher (prefix+S) needs fzf, and the collector serializes itself with
  # flock (util-linux on Linux; macOS falls back to Perl).
  tmuxDeps =
    { lib, pkgs }:
    with pkgs;
    [
      fzf
      jq
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      wl-clipboard
      util-linux
    ];
  # tmux-ssh-split and samleeney/tmux-agent-status are not yet in nixpkgs'
  # tmuxPlugins, so build them from upstream tarballs. Each is a tmux plugin
  # with an .rtp passthru so home-manager can run-shell it like any other
  # plugin. tmux-ssh-split is upstream (its pgid-based detection works outside
  # the devenv nested-pty case, which we don't support for SSH splits).
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
  # opencode is tracked via the opencode-session-status event plugin (its JSON
  # is keyed by TMUX_PANE), which the appended bridge maps onto the per-pane
  # status files this plugin's collector reads. claude/codex/devin are
  # presence-detected automatically; hook-based live states need their per-CLI
  # hooks configured, which nixconf does not manage.
  opencodeBridgeSrc = builtins.readFile ../../config/tmux/patches/opencode-bridge.sh;
  agentStatus =
    { pkgs }:
    let
      opencodeBridge = pkgs.writeText "opencode-bridge.sh" opencodeBridgeSrc;
    in
    pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "tmuxplugins-agent-status";
      version = "c5babfbc";
      src = pkgs.fetchurl {
        url = "https://github.com/samleeney/tmux-agent-status/archive/${finalAttrs.version}.tar.gz";
        hash = "sha256-aN53VqMjccpgJsSrPMAY6ZXC8D/DJSnwWFqYuS+hego=";
      };
      dontBuild = true;
      # Needed in the sandbox so installPhase can `cat` it.
      nativeBuildInputs = [ opencodeBridge ];
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/tmux-plugins/tmux-agent-status
        cp -r tmux-agent-status.tmux hooks scripts sounds README.md $out/share/tmux-plugins/tmux-agent-status/
        # opencode bridge: call it at the top of collect_data, then append the
        # function itself. Writes are tmp+mv + change-only so the collector's
        # mtime fast-path keeps skipping rebuilds while nothing changes.
        sed -i '/^collect_data() {$/a\    opencode_state_bridge' \
          $out/share/tmux-plugins/tmux-agent-status/scripts/lib/collect.sh
        cat ${opencodeBridge} >> $out/share/tmux-plugins/tmux-agent-status/scripts/lib/collect.sh
        chmod +x $out/share/tmux-plugins/tmux-agent-status/tmux-agent-status.tmux \
          $out/share/tmux-plugins/tmux-agent-status/scripts/*.sh \
          $out/share/tmux-plugins/tmux-agent-status/hooks/*.sh
        runHook postInstall
      '';
      passthru.rtp = "${finalAttrs.finalPackage}/share/tmux-plugins/tmux-agent-status/tmux-agent-status.tmux";
      meta = {
        description = "AI agent session manager for tmux: sidebar, fzf switcher, hook-based Claude/Codex status (plus opencode via nixconf bridge)";
        homepage = "https://github.com/samleeney/tmux-agent-status";
        license = pkgs.lib.licenses.mit;
      };
    });
  tmuxCfg =
    { pkgs }:
    let
      sshSplitPkg = sshSplit { inherit pkgs; };
      agentStatusPkg = agentStatus { inherit pkgs; };
    in
    {
      enable = true;
      # home-manager writes this in the base config (before any plugin
      # run-shell), so continuum's background auto-restore — which spawns panes
      # before extraConfig is applied — already has a zsh default-shell to fall
      # back to instead of the passwd login shell.
      shell = "${pkgs.zsh}/bin/zsh";
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
            set -g @continuum-save-interval '10'
          '';
        }
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
          # Live agent status (sidebar + status-line summary) from
          # samleeney/tmux-agent-status. Agent states come from hooks for
          # claude/codex/devin and from the opencode-session-status bridge for
          # opencode. Default keys: prefix+S switcher, prefix+o sidebar,
          # prefix+N next done, prefix+W wait, prefix+p park.
          plugin = agentStatusPkg;
          extraConfig = ''
            set -g @agent-notification-sound none
          '';
        }
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
        # tmux-agent-status' pulses and sidebar need a 1s status-interval.
        set -g status-interval 1
        # Continuum drives its periodic auto-save off a `#()` hook in the status
        # line. We own status-right here (catppuccin), so re-inject the hook;
        # otherwise the theme overwriting status-right silently kills auto-save.
        # tmux-agent-status' status-line summary is injected the same way (its
        # own status-right append runs before extraConfig and gets overwritten).
        set -g status-right "#(${agentStatusPkg}/share/tmux-plugins/tmux-agent-status/scripts/status-line.sh) #(${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh)#{E:@catppuccin_status_user}#{E:@catppuccin_status_host}#{E:@catppuccin_status_session}"
        set -g pane-border-lines simple
        set -g pane-active-border-style "fg=#fab387"
        set -g renumber-windows on
        set -sg escape-time 0
        set -g history-limit 50000
        set -g display-time 4000
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
        # --- Prompt navigation (OSC 133 semantic markers) ---
        # Jump between shell prompts in scrollback instead of scrolling; the
        # markers are emitted by the shell (config/shell/zsh-extra.zsh).
        bind-key -T copy-mode-vi '[' send-keys -X previous-prompt
        bind-key -T copy-mode-vi ']' send-keys -X next-prompt
        # Jump straight to the start of the most recent command from the shell
        # without touching copy-mode first (single keypress; q exits).
        bind P copy-mode \; send-keys -X previous-prompt \; send-keys -X clear-selection
        # Copy the previous command's output to the system clipboard: the -o
        # flag moves to the command output's START mark, so the selection spans
        # exactly the output lines between that mark and the current prompt.
        bind-key -T copy-mode-vi 'Y' send-keys -X previous-prompt -o \; send-keys -X begin-selection \; send-keys -X history-bottom \; send-keys -X cursor-up \; send-keys -X copy-selection-and-cancel
        bind f resize-pane -Z
        bind q detach-client
        bind e choose-window -Z
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
        # SSH host picker: popup -> pick a host from ~/.ssh/config -> attach a
        # tmux session on it (persistent) or a plain shell. Bound to h (not S:
        # prefix+S belongs to the tmux-agent-status fzf target switcher).
        bind h display-popup -w 70% -h 60% -E "${pkgs.writeShellScript "ssh-switcher" (builtins.readFile ../../config/tmux/ssh-switcher.sh)}"
        # Session/window switcher on tv (television), same pattern as R. The
        # script content is inlined via readFile so the store wrapper is
        # executable regardless of the git mode of the source file.
        bind F display-popup -w 70% -h 60% -E "${pkgs.writeShellScript "session-switcher" (builtins.readFile ../../config/tmux/session-switcher.sh)}"
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
          "SSH host"     h "display-popup -w 70% -h 60% -E 'exec bash ${../../config/tmux/nixconf-menu.sh} ssh'" \
          "Exit"         q ""
        set -g set-titles on
        set -g set-titles-string "#S - #W"
        set -g status-position top
        set -g status-left-length 100
        set -g status-right-length 140
        set -g status-left "#{E:@catppuccin_status_application}"
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
          home.packages = tmuxDeps { inherit lib pkgs; };
        };
      };
    };

  flake.modules.homeManager.tmux =
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
        programs.zsh.shellAliases = tmuxAliases;
        home.packages = tmuxDeps { inherit lib pkgs; };
        # The plugin's scripts need bash 4+ (associative arrays); macOS ships
        # bash 3.2, so point the plugin at nixpkgs' bash.
        home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          TMUX_AGENT_STATUS_BASH = "${pkgs.bash}/bin/bash";
        };
      };
    };
}
