{ lib, ... }: {
  flake.modules.nixos.secrets = { config, lib, ... }: {
    options.modules.secrets = {
      userName = lib.mkOption { type = lib.types.str; default = "alexis.pigeon"; };
      gitEmail = lib.mkOption { type = lib.types.str; default = "you@example.com"; };
    };
    config = {
      sops = {
        defaultSopsFile = ./../secrets/secrets.yaml;
        age.keyFile = "/var/lib/sops-nix/key.txt";
        age.sshKeyPaths = [ ];
        secrets."github-deploy-key" = { path = "/home/${config.modules.secrets.userName}/.ssh/github-deploy-key"; owner = config.modules.secrets.userName; group = "users"; mode = "0600"; };
      };
      programs.ssh.extraConfig = "Host github.com\n  IdentityFile ~/.ssh/github-deploy-key\n  IdentitiesOnly yes\n";
      programs.git = { enable = true; config = { user.name = config.modules.secrets.userName; user.email = config.modules.secrets.gitEmail; }; };
    };
  };
}
