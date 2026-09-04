{
  lib,
  ...
}:
{
  flake.modules.nixos.network =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.network.enable = lib.mkEnableOption "NetworkManager + firewall defaults";
      config = lib.mkIf config.modules.network.enable {
        networking = {
          hostName = lib.mkDefault "nixos";
          networkmanager.enable = lib.mkDefault true;
          firewall = {
            enable = lib.mkDefault true;
            allowedTCPPorts = lib.mkDefault [ ];
          };
        };
      };
    };
}
