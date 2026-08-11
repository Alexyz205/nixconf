{ lib, ... }: {
  flake.modules.nixos.network = { ... }: {
    networking.hostName = lib.mkDefault "nixos";
    networking.networkmanager.enable = lib.mkDefault true;
    networking.firewall.enable = lib.mkDefault true;
    networking.firewall.allowedTCPPorts = lib.mkDefault [ ];
  };
}
