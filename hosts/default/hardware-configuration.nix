# Hardware configuration for the `default` host.
#
# Mounting/partitioning is NOT here — it comes from the disko module
# (nixos-modules/disko.nix). This file holds host-specific hardware:
# CPU microcode, GPU drivers, firmware, etc.
{ config, lib, ... }:

{
  # CPU microcode (uncomment for AMD or Intel):
  # hardware.cpu.amd.updateMicrocode = true;
  # hardware.cpu.intel.updateMicrocode = true;

  # GPU drivers (uncomment the one matching this machine):
  # hardware.graphics.enable = true;  # generic / AMD (mesa)
  # services.xserver.videoDrivers = [ "nvidia" ];

  # enable all firmware / non-free where needed:
  # hardware.enableAllFirmware = lib.mkDefault true;
}
