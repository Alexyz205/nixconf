{
  lib,
  ...
}:
let
  # Force the desktop app to render through XWayland instead of native Wayland:
  # on NVIDIA Wayland the Electron renderer enters a continuous-repaint loop
  # (keeps receiving frame callbacks) and burns a full core while idle.
  # See bitwarden/clients#17996 (Wayland + NVIDIA GPU/dmabuf issues); Bitwarden's
  # own release notes recommend switching the desktop app to X11 on Linux.
  mkBitwardenDesktop =
    pkgs:
    pkgs.symlinkJoin {
      name = "bitwarden-desktop-x11";
      paths = [ pkgs.bitwarden-desktop ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/bitwarden --add-flags "--ozone-platform=x11"
      '';
    };

  # Options shared by the NixOS and home-manager sides.
  bitwardenOptions = {
    enable = lib.mkEnableOption "Bitwarden CLI + desktop client (self-hosted Vaultwarden)";
    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://vault.alexyz.hl";
      description = "Self-hosted Bitwarden/Vaultwarden server URL.";
    };
    desktop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also install the Bitwarden desktop app (GUI).";
    };
  };

  # Shared home-manager config: the CLI (+ optional desktop app), the
  # self-hosted server URL, and zsh helpers. Values are passed in explicitly so
  # the NixOS side doesn't depend on home-manager option space.
  mkHmCfg =
    {
      pkgs,
      serverUrl,
      desktop,
    }:
    {
      home.packages = [ pkgs.bitwarden-cli ] ++ lib.optionals desktop [ (mkBitwardenDesktop pkgs) ];
      home.sessionVariables = {
        BW_SERVER = serverUrl;
      };
      # The desktop app auto-creates ~/.config/autostart/bitwarden.desktop on
      # first run pointing at the RAW bitwarden-desktop store path, so login
      # starts a Wayland instance and the NVIDIA repaint loop burns a full core
      # (the --ozone-platform=x11 wrapper is never used). Ship our own autostart
      # entry that targets the wrapped binary instead.
      xdg.configFile."autostart/bitwarden.desktop" = lib.mkIf desktop {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Bitwarden
          Comment=Bitwarden startup script
          Exec=${mkBitwardenDesktop pkgs}/bin/bitwarden --autostart
          StartupNotify=false
          Terminal=false
        '';
      };
      programs.zsh.initContent = lib.mkOrder 950 ''
        # Bitwarden CLI helpers (self-hosted Vaultwarden: $BW_SERVER)
        bwu() { export BW_SESSION="$(bw unlock --raw)" }
        bwl() { bw lock; unset BW_SESSION }
      '';
    };

  # Wire the shared config from the module options (same shape on both sides).
  mkCfg =
    {
      config,
      pkgs,
    }:
    mkHmCfg {
      inherit pkgs;
      serverUrl = config.modules.bitwarden.serverUrl;
      desktop = config.modules.bitwarden.desktop;
    };
in
{
  flake.modules.nixos.bitwarden =
    {
      config,
      pkgs,
      ...
    }:
    {
      options.modules.bitwarden = bitwardenOptions;
      config = lib.mkIf config.modules.bitwarden.enable {
        environment.systemPackages = [
          pkgs.bitwarden-cli
        ]
        ++ lib.optionals config.modules.bitwarden.desktop [ (mkBitwardenDesktop pkgs) ];
        home-manager.users.${config.modules.users.userName} = mkCfg {
          inherit config pkgs;
        };
      };
    };

  flake.modules.homeManager.bitwarden =
    {
      config,
      pkgs,
      ...
    }:
    {
      options.modules.bitwarden = bitwardenOptions;
      config = lib.mkIf config.modules.bitwarden.enable (mkCfg {
        inherit config pkgs;
      });
    };
}
