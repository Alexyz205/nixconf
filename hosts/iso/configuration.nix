# Host: `iso` — the live/installer ISO.
#
# This is NOT a real machine. It layers the shared tooling on top of the
# official minimal installer, so the live environment has what you need to
# install any host. It does NOT enable the hardened modules — the ISO is
# deliberately a plain rescue/install tool.
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
