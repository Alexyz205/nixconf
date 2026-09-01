{ lib, ... }: {
  flake.modules.nixos.network = _: {
    networking = {
      hostName = lib.mkDefault "nixos";
      networkmanager.enable = lib.mkDefault true;
      firewall = {
        enable = lib.mkDefault true;
        allowedTCPPorts = lib.mkDefault [ ];
      };
    };
  };
}
