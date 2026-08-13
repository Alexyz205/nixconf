{lib, ...}: let
  secretsYaml = ./../secrets/secrets.yaml;
  yubiIdentity = ./config/sops/yubi-age-identity;
in {
  flake.modules.nixos.secrets = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.secrets = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = "alexis";
      };
      gitEmail = lib.mkOption {
        type = lib.types.str;
        default = "anathos205@gmail.com";
      };
    };
    config = {
      sops = {
        defaultSopsFile = secretsYaml;
        age.keyFile = "/etc/yubi-age-identity";
        age.sshKeyPaths = [];
        age.generateKey = false;
        age.plugins = [pkgs.age-plugin-yubikey];
        gnupg.sshKeyPaths = [];
      };
      environment.etc."yubi-age-identity".source = yubiIdentity;
      programs.git = {
        enable = true;
        config = {
          user.name = config.modules.secrets.userName;
          user.email = config.modules.secrets.gitEmail;
        };
      };
    };
  };
}
