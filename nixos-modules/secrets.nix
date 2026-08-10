# Secrets module: sops-nix encrypted GitHub deploy key + git identity.
# Enable with `modules.secrets.enable = true` AFTER the one-time bootstrap
# (README "Private repos via encrypted deploy key"), otherwise the first
# activation fails because the secret file is empty.
#
# Best practice: every host that clones private repos or commits gets its
# OWN age key (one per machine). Add each machine's public key to .sops.yaml.
{ config, lib, ... }:

{
  options.modules.secrets = {
    enable = lib.mkEnableOption "sops-nix encrypted secrets";
    userName = lib.mkOption {
      type = lib.types.str;
      default = "alexis";
    };
    gitEmail = lib.mkOption {
      type = lib.types.str;
      default = "you@example.com";
    };
  };

  config = lib.mkIf config.modules.secrets.enable {
    sops = {
      defaultSopsFile = ./../secrets/secrets.yaml;
      # Age key lives on the machine, root-only. We bring it there once
      # (scp) rather than having sops auto-generate it (generateKey),
      # so we always know the matching public key for .sops.yaml.
      age.keyFile = "/var/lib/sops-nix/key.txt";
      # Don't reuse the ssh host key for age decryption: keep the two
      # keypairs independent.
      age.sshKeyPaths = [ ];
      secrets = {
        # Contents = the PRIVATE key generated with:
        #   ssh-keygen -t ed25519 -f github-deploy-key -C "nixos@github"
        # Public half goes to GitHub -> Settings -> SSH and GPG keys.
        "github-deploy-key" = {
          path = "/home/${config.modules.secrets.userName}/.ssh/github-deploy-key";
          owner = config.modules.secrets.userName;
          group = "users";
          mode = "0600";
        };
      };
    };

    # Always offer only the deploy key to github.com, never the login key.
    programs.ssh.extraConfig = ''
      Host github.com
        IdentityFile ~/.ssh/github-deploy-key
        IdentitiesOnly yes
    '';

    # git identity for commits made on this machine.
    programs.git = {
      enable = true;
      config = {
        user.name = config.modules.secrets.userName;
        user.email = config.modules.secrets.gitEmail;
      };
    };
  };
}
