# Customization layer for our ISO.
#
# This module is layered ON TOP of the official minimal installer
# (imported in flake.nix). Everything we add here lands in the
# live environment AND the installer.
{ lib, pkgs, ... }:

{
  # Use the latest Linux kernel for newer hardware support.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Support extra filesystems for rescue/repair work.
  # mkForce is needed because the installer defines its own list.
  boot.supportedFilesystems = lib.mkForce [
    "btrfs"
    "reiserfs"
    "vfat"
    "f2fs"
    "xfs"
    "ntfs"
    "cifs"
  ];

  # Packages preinstalled in the live environment.
  environment.systemPackages = with pkgs; [
    curl
    wget
    htop
    tmux
    ripgrep
    fd
    vim
    # nix-related tools, handy while learning
    nix-tree
    nix-output-monitor
  ];
}
