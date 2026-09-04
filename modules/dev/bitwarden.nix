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
    }:
    {
      home.packages = [ pkgs.bitwarden-cli ] ++ lib.optionals desktop [ pkgs.bitwarden-desktop ];
      home.sessionVariables.BW_SERVER = serverUrl;
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
      };
      config = lib.mkIf config.modules.bitwarden.enable {
        environment.systemPackages = [
          pkgs.bitwarden-cli
        ]
        ++ lib.optionals config.modules.bitwarden.desktop [ pkgs.bitwarden-desktop ];
        home-manager.users.${config.modules.users.userName} = mkHmCfg {
          inherit pkgs;
          serverUrl = config.modules.bitwarden.serverUrl;
          desktop = config.modules.bitwarden.desktop;
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
      };
      config = lib.mkIf config.modules.bitwarden.enable (mkHmCfg {
        inherit pkgs;
        serverUrl = config.modules.bitwarden.serverUrl;
        desktop = config.modules.bitwarden.desktop;
      });
    };
}
