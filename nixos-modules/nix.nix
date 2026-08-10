# Nix module: daemon hardening.
# Enable with `modules.nix.enable = true`.
{ config, lib, ... }:

{
  options.modules.nix = {
    enable = lib.mkEnableOption "nix hardening";
  };

  config = lib.mkIf config.modules.nix.enable {
    # Only wheel users may run nix commands.
    nix.settings.allowed-users = [ "@wheel" ];
  };
}
