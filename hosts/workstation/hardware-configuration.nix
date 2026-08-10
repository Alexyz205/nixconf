# Hardware configuration for the `workstation` host.
#
# Mounting/partitioning is NOT here — it comes from the disko module
# (nixos-modules/disko.nix). This file holds host-specific hardware:
# CPU microcode, GPU drivers, firmware, etc.
{ config, lib, ... }:

{
  # CPU microcode (uncomment for AMD or Intel):
  # hardware.cpu.amd.updateMicrocode = true;
  # hardware.cpu.intel.updateMicrocode = true;

  # enable all firmware / non-free where needed:
  # hardware.enableAllFirmware = lib.mkDefault true;
}
