{ lib, ... }: {
  flake.modules.nixos.ssh = { ... }: {
    services.openssh = { enable = true; settings = { PasswordAuthentication = false; KbdInteractiveAuthentication = false; PermitRootLogin = "no"; }; };
    services.fail2ban.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkDefault [ 22 ];
  };
}
