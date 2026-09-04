{
  lib,
  ...
}:
let
  # Shared home-manager config: the CLI (+ optional desktop app), the
  # self-hosted server URL, and zsh helpers. Values are passed in explicitly so
  # the NixOS side doesn't depend on home-manager option space.
  mkHmCfg =
    {
      pkgs,
      serverUrl,
      desktop,
      caCertFile,
    }:
    {
      home.packages = [ pkgs.bitwarden-cli ] ++ lib.optionals desktop [ pkgs.bitwarden-desktop ];
      home.sessionVariables = {
        BW_SERVER = serverUrl;
      }
      // lib.optionalAttrs (caCertFile != null) {
        # Node.js ignores the system trust store and only honors this var.
        # Points at the homelab root CA (a store path) so `bw` can verify the
        # Traefik-issued *.alexyz.hl cert.
        NODE_EXTRA_CA_CERTS = "${caCertFile}";
      };
      programs.zsh.initContent = lib.mkOrder 950 ''
        # Bitwarden CLI helpers (self-hosted Vaultwarden: $BW_SERVER)
        bwu() { export BW_SESSION="$(bw unlock --raw)" }
        bwl() { bw lock; unset BW_SESSION }
      '';
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
      options.modules.bitwarden = {
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
        caCertFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            CA certificate (PEM) that issues the server's TLS cert, e.g. the
            homelab cert-manager root CA. Added to the system trust store
            (fixes the desktop app + Chromium-based browsers) and exported as
            NODE_EXTRA_CA_CERTS (fixes the Node.js CLI). Null when the server
            uses a publicly-trusted certificate.
          '';
        };
      };
      config = lib.mkIf config.modules.bitwarden.enable {
        environment.systemPackages = [
          pkgs.bitwarden-cli
        ]
        ++ lib.optionals config.modules.bitwarden.desktop [ pkgs.bitwarden-desktop ];
        security.pki.certificateFiles = lib.mkIf (config.modules.bitwarden.caCertFile != null) [
          config.modules.bitwarden.caCertFile
        ];
        home-manager.users.${config.modules.users.userName} = mkHmCfg {
          inherit pkgs;
          serverUrl = config.modules.bitwarden.serverUrl;
          desktop = config.modules.bitwarden.desktop;
          caCertFile = config.modules.bitwarden.caCertFile;
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
      options.modules.bitwarden = {
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
        caCertFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            CA certificate (PEM) that issues the server's TLS cert, e.g. the
            homelab cert-manager root CA. Exported as NODE_EXTRA_CA_CERTS so
            the Node.js CLI can verify the self-hosted server. Null when the
            server uses a publicly-trusted certificate.
          '';
        };
      };
      config = lib.mkIf config.modules.bitwarden.enable (mkHmCfg {
        inherit pkgs;
        serverUrl = config.modules.bitwarden.serverUrl;
        desktop = config.modules.bitwarden.desktop;
        caCertFile = config.modules.bitwarden.caCertFile;
      });
    };
}
