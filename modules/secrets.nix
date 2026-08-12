{lib, ...}: let
  secretsYaml = ./../secrets/secrets.yaml;
in {
  flake.modules.nixos.secrets = {
    config,
    lib,
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
        age.keyFile = "/var/lib/sops-nix/key.txt";
        age.sshKeyPaths = [];
        # Auto-generate the host age key on first activation; secrets/secrets.yaml
        # stays a plaintext template until it is sops-encrypted (see README).
        age.generateKey = true;
      };
      # Deploy a secret by adding its key to secrets/secrets.yaml (via sops), then
      # declaring it here, e.g.:
      #   sops.secrets.sample-secret = {
      #     path = "/home/${config.modules.secrets.userName}/.config/sample-secret";
      #     owner = config.modules.secrets.userName;
      #     group = "users";
      #     mode = "0600";
      #   };
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