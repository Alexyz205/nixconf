# Bootloader module: systemd-boot (UEFI).
# Enable with `modules.boot.enable = true`.
{ config, lib, ... }:

{
  options.modules.boot = {
    enable = lib.mkEnableOption "systemd-boot (UEFI)";
  };

  config = lib.mkIf config.modules.boot.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
