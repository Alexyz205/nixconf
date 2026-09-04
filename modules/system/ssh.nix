{ lib, ... }:
let
  # Shared SSH client config. The default identity is the plain `id_ed25519`
  # key; feature modules append their own keys (e.g. the resident YubiKey) via
  # `modules.ssh.identityFiles`. `SecurityKeyProvider internal` is the OpenSSH
  # default for FIDO2/`-sk` keys and is inert when none are present.
  sshClient =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.ssh = {
        enable = lib.mkEnableOption "SSH client config";
        identityFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra identity files appended after the default ~/.ssh/id_ed25519";
        };
      };
      config = lib.mkIf config.modules.ssh.enable {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          # devpod keeps its Host *.devpod entries in its own writable file
          # (SSH_CONFIG_PATH) because this config is a read-only store symlink.
          includes = [ "~/.config/devpod/ssh_config" ];
          settings."*" = {
            IdentityFile = [ "~/.ssh/id_ed25519" ] ++ config.modules.ssh.identityFiles;
            IdentitiesOnly = "yes";
            SecurityKeyProvider = "internal";
            IdentityAgent = "none";
          };
        };
      };
    };
in
{
  flake.modules.nixos.ssh =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.ssh.enable = lib.mkEnableOption "SSH server (openssh + fail2ban)";
      config = lib.mkIf config.modules.ssh.enable {
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
          };
        };
        services.fail2ban.enable = true;
        networking.firewall.allowedTCPPorts = lib.mkDefault [ 22 ];
      };
    };

  flake.modules.homeManager.ssh = sshClient;
}
