{
  inputs,
  config,
  ...
}: let
  envFile = ../../secrets/env.yaml;
  yubiIdentity = ../../config/sops/yubi-age-identity;
  homeSopsModule = config.flake.modules.homeManager.sops;
in {
  flake.modules.nixos.sops = {
    config,
    pkgs,
    ...
  }: {
    config = {
      sops = {
        defaultSopsFile = envFile;
        age.keyFile = "/etc/yubi-age-identity";
        age.sshKeyPaths = [];
        age.generateKey = false;
        age.plugins = [pkgs.age-plugin-yubikey];
        gnupg.sshKeyPaths = [];
      };
      environment.etc."yubi-age-identity".source = yubiIdentity;
      home-manager.sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
        homeSopsModule
      ];
      home-manager.users.${config.modules.users.userName}.modules.sops.enable = true;
    };
  };

  flake.modules.homeManager.sops = {
    config,
    lib,
    pkgs,
    ...
  }: let
    secretExports =
      let
        exportVar = name: secret:
          lib.optionalString (secret ? path && (secret.sopsFile or envFile) == envFile) ''
            if [ -r "${secret.path}" ]; then
              export ${name}="$(cat "${secret.path}")"
            fi
          '';
      in
        builtins.concatStringsSep "" (lib.mapAttrsToList exportVar (config.sops.secrets or {}));
    sopsAliases = {
      sec = "SOPS_AGE_KEY_FILE=$NIXCONF/config/sops/yubi-age-identity sops $NIXCONF/secrets/secrets.yaml";
      sece = "SOPS_AGE_KEY_FILE=$NIXCONF/config/sops/yubi-age-identity sops $NIXCONF/secrets/env.yaml";
    };
  in {
    options.modules.sops.enable = lib.mkEnableOption "Sops secrets (env.yaml, GITHUB_TOKEN, sec/sece aliases)";
    # The sops-nix base module is imported at the composition level (paired with
    # this feature + enable in home-manager.nix), so hosts without a YubiKey
    # (server, containers) never pull it in.
    config = lib.mkIf config.modules.sops.enable {
      sops = {
        age.keyFile = "${config.home.homeDirectory}/repos/personal/nixconf/config/sops/yubi-age-identity";
        age.plugins = [pkgs.age-plugin-yubikey];
        defaultSopsFile = envFile;
        secrets.GITHUB_TOKEN = {};
      };
      programs.zsh.shellAliases = sopsAliases;
      programs.zsh.initContent = lib.mkOrder 950 secretExports;
    };
  };
}