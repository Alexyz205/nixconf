{
  nixconf.modules.nixos.moonshine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.moonshine;
      steam = config.programs.steam.package;
      heroic = config.modules.heroic.package;
      sh = lib.getExe pkgs.bash;
      pgrep = lib.getExe' pkgs.procps "pgrep";
      seq = lib.getExe' pkgs.coreutils "seq";
      sleep = lib.getExe' pkgs.coreutils "sleep";

      # Steam is single-instance per user: if the desktop Steam is running, a
      # stream would just forward the steam:// URL to it and exit instead of
      # running in Moonshine's compositor (moonshine issue #134). Ask it to shut
      # down and wait (up to ~30s) before launching the streaming instance.
      closeDesktopSteam = [
        sh
        "-c"
        "if ${pgrep} -x steam >/dev/null; then ${lib.getExe steam} -shutdown &>/dev/null; for _ in $(${seq} 1 30); do ${pgrep} -x steam >/dev/null || break; ${sleep} 1; done; fi"
      ];
    in
    {
      options.modules.moonshine = {
        enable = lib.mkEnableOption "Moonshine headless Moonlight/GameStream host";
        name = lib.mkOption {
          type = lib.types.str;
          default = "nixconf";
          description = "Name advertised to Moonlight clients.";
        };
        firewallInterfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Interfaces on which to open the Moonlight/GameStream ports. Empty
            keeps them closed; list the LAN interface to allow streaming. The
            GameStream protocol is not fully encrypted, so never expose these
            ports to the internet (use a VPN instead).
          '';
        };
        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra packages on the service PATH for launched apps.";
        };
        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra Moonshine TOML config, merged over the defaults.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.moonshine = {
          enable = true;
          user = config.modules.users.userName;
          inherit (cfg) firewallInterfaces extraPackages;
          # Moonshine gives each stream its own isolated Smithay compositor at
          # the client's negotiated resolution, so no monitor/HDMI dummy or
          # virtual output is needed: the Xbox gets a clean 16:9 1080p session
          # while niri keeps the real desktop.
          settings = lib.recursiveUpdate {
            inherit (cfg) name;
            # Bind everywhere; LAN-only access is enforced by firewallInterfaces.
            address = "0.0.0.0";

            application = [
              {
                title = "Steam Big Picture";
                command = [
                  (lib.getExe steam)
                  "steam://open/bigpicture"
                ];
                pre_command = [ closeDesktopSteam ];
                # Capture app output in the journal (default is null) so a
                # failed launch can be debugged with:
                #   journalctl --user -u moonshine-session.service
                stdout = "journal";
                stderr = "journal";
              }
            ];

            # Expose every installed Steam game directly in Moonlight, plus
            # Heroic (GOG/Epic/Amazon) titles when the Heroic feature is on.
            application_scanner = [
              {
                type = "steam";
                library = "$HOME/.local/share/Steam";
                command = [
                  (lib.getExe steam)
                  "-bigpicture"
                  "steam://rungameid/{game_id}"
                ];
                stdout = "journal";
                stderr = "journal";
              }
            ]
            ++ lib.optionals config.modules.heroic.enable [
              # --no-gui keeps Heroic's own window out of the stream.
              # --launcher-skip is read by CD Projekt REDprelauncher
              # (The Witcher 3, Cyberpunk 2077): without it those games show
              # the REDlauncher instead of starting (Heroic issue #2202).
              {
                type = "heroic";
                command = [
                  (lib.getExe heroic)
                  "--no-gui"
                  "heroic://launch?appName={app_name}&runner={runner}&arg=--launcher-skip"
                ];
                stdout = "journal";
                stderr = "journal";
              }
            ];
          } cfg.settings;
        };
      };
    };
}
