# ISO: `proxmox` — live/installer ISO for a default Proxmox VM.
#
# This is NOT a real machine. It layers the shared tooling on top of the
# official minimal installer, so the live environment has what you need to
# install any host. It does NOT enable the hardened modules — the ISO is
# deliberately a plain rescue/install tool.
#
# Identity: every ISO purpose gets a distinct `isoImage.edition` so the
# built image, volume ID and boot menu are recognisable. Add another ISO
# for a different purpose by copying this file (new edition) + one line in
# flake.nix (mkIso).
{ lib, pkgs, ... }:

{
  # Give this ISO a distinct identity:
  #   file:      nixos-proxmox-<version>-x86_64-linux.iso
  #   volume ID: nixos-proxmox-<release>-x86_64
  isoImage.edition = "proxmox";
  # Show the purpose in the GRUB/syslinux boot menu entry.
  isoImage.configurationName = "Proxmox VM";
  # Identify the live environment (visible in `hostnamectl`, prompt, ...).
  networking.hostName = "nixos-proxmox";

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

  # QEMU guest agent: lets Proxmox display the VM's IP / do graceful
  # shutdown while the installer is running inside the VM.
  services.qemuGuest.enable = true;

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
