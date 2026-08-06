# sops-nix: encrypted secrets for this machine.
#
# Secret managed here: the GitHub deploy key (~/.ssh/github-deploy-key),
# used to clone private repos.
#
# IMPORTANT (bootstrap order):
#   1. Install the system first (this module is NOT yet imported in flake.nix).
#   2. Do the one-time bootstrap in README "Private repos via encrypted deploy key".
#   3. Then uncomment the sops-nix import in flake.nix and rebuild.
# Otherwise the very first activation fails because the secret file is empty.
{ lib, ... }:

{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
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
        path = "/home/alexis/.ssh/github-deploy-key"; # CHANGE ME if username differs
        owner = "alexis";                            # CHANGE ME
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
    userName = "alexis";          # CHANGE ME
    userEmail = "you@example.com"; # CHANGE ME
  };
}
