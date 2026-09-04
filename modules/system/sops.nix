{
  inputs,
  config,
  lib,
  ...
}:
let
  envFile = ../../secrets/env.yaml;
  yubiIdentity = ../../config/sops/yubi-age-identity;
  homeSopsModule = config.flake.modules.homeManager.sops;
in
{
  flake.modules.nixos.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.sops = {
        enable = lib.mkEnableOption "Sops secrets (NixOS side)";
        useYubikey = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether the age identity lives on a YubiKey. When false, skips the
            age-plugin-yubikey package and the /etc/yubi-age-identity
            provisioning (hosts without YubiKey access).
          '';
        };
        ageKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "/etc/yubi-age-identity";
          description = ''
            Age identity file used to decrypt sops secrets. Defaults to the
            YubiKey identity; point at a software age key on hosts without
            YubiKey access (e.g. the workstation).
          '';
        };
      };
      config = lib.mkIf config.modules.sops.enable {
        sops = {
          defaultSopsFile = envFile;
          age = {
            keyFile = lib.mkDefault config.modules.sops.ageKeyFile;
            sshKeyPaths = [ ];
            generateKey = false;
            plugins = lib.mkIf config.modules.sops.useYubikey [ pkgs.age-plugin-yubikey ];
          };
          gnupg.sshKeyPaths = [ ];
        };
        environment.etc."yubi-age-identity" = lib.mkIf config.modules.sops.useYubikey {
          source = yubiIdentity;
        };
        home-manager.sharedModules = [
          inputs.sops-nix.homeManagerModules.sops
          homeSopsModule
        ];
        home-manager.users.${config.modules.users.userName}.modules.sops.enable = true;
      };
    };

  flake.modules.homeManager.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      secretExports =
        let
          exportVar =
            name: secret:
            lib.optionalString (secret ? path && (secret.sopsFile or envFile) == envFile) ''
              if [ -r "${secret.path}" ]; then
                export ${name}="$(cat "${secret.path}")"
              fi
            '';
        in
        builtins.concatStringsSep "" (lib.mapAttrsToList exportVar (config.sops.secrets or { }));
      sopsAliases = {
        sec = "SOPS_AGE_KEY_FILE=${config.modules.sops.ageKeyFile} sops $NIXCONF/secrets/secrets.yaml";
        sece = "SOPS_AGE_KEY_FILE=${config.modules.sops.ageKeyFile} sops $NIXCONF/secrets/env.yaml";
      };
    in
    {
      options.modules.sops = {
        enable = lib.mkEnableOption "Sops secrets (env.yaml, GITHUB_TOKEN, sec/sece aliases)";
        ageKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/repos/personal/nixconf/config/sops/yubi-age-identity";
          description = ''
            Age identity file used to decrypt sops secrets. Defaults to the
            YubiKey identity; point at a software age key on hosts without
            YubiKey access (e.g. the workstation).
          '';
        };
      };
      # The sops-nix base module is imported at the composition level (paired with
      # this feature + enable in home-manager.nix), so hosts without a YubiKey
      # (server, containers) never pull it in.
      config = lib.mkIf config.modules.sops.enable {
        sops = {
          age = {
            keyFile = config.modules.sops.ageKeyFile;
            plugins = [ pkgs.age-plugin-yubikey ];
          };
          defaultSopsFile = envFile;
          secrets.GITHUB_TOKEN = { };
        };
        programs.zsh.shellAliases = sopsAliases;
        programs.zsh.initContent = lib.mkOrder 950 (
          secretExports
          + ''
            export SOPS_AGE_KEY_FILE="${config.modules.sops.ageKeyFile}"
          ''
        );
      };
    };
}
