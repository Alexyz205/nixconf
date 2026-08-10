# SSH module: hardened OpenSSH server + fail2ban.
# Enable with `modules.ssh.enable = true`.
{ config, lib, ... }:

{
  options.modules.ssh = {
    enable = lib.mkEnableOption "hardened SSH server";
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf config.modules.ssh.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # Brute-force protection for sshd.
    services.fail2ban.enable = true;

    # Open port 22 on the firewall.
    networking.firewall.allowedTCPPorts = [ 22 ];
  };
}
