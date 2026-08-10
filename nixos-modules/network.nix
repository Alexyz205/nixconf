# Network module: hostname, NetworkManager, firewall.
# Enable with `modules.network.enable = true`.
{ config, lib, ... }:

{
  options.modules.network = {
    enable = lib.mkEnableOption "networking";
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
    };
    networkmanager = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    # Open extra ports (e.g. [ 22 ]). SSH's own port is added by the ssh module.
    openPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
    };
  };

  config = lib.mkIf config.modules.network.enable {
    networking.hostName = config.modules.network.hostName;
    networking.networkmanager.enable = config.modules.network.networkmanager;

    # Firewall: deny by default, open only what hosts/services declare.
    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = config.modules.network.openPorts;
  };
}
