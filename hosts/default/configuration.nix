# Host: `default` — the main machine (dev / remote work box), CLI only.
#
# Enables the shared modules it needs. Everything not listed is off.
# The per-user CLI toolchain (neovim, tmux, starship, gh, opencode, ...)
# comes from MISE, not from Nix (see nixos-modules/shell.nix).
{ config, lib, ... }:

{
  imports = [
    # Shared, toggleable module library (video pattern).
    ../../nixos-modules
    # Host-specific hardware (CPU microcode, GPU, etc.).
    ./hardware-configuration.nix
  ];

  system.stateVersion = "24.11";

  modules = {
    boot.enable = true;

    network = {
      enable = true;
      hostName = "default";
      # openPorts: extra non-SSH ports this host listens on.
      openPorts = [ ];
    };

    security.enable = true;
    ssh.enable = true;
    podman.enable = true;
    nix.enable = true;

    users = {
      enable = true;
      userName = "alexis";
      # Add your public SSH key(s) here for remote login.
      authorizedKeys = [ ];
    };

    shell.enable = true;
    dotfiles.enable = true;

    packages = {
      enable = true;
      basic = true;      # curl, wget, openssl
      containers = true; # devpod, docker-compose, podman-compose
      security = true;   # pass, age, sops, gnupg
    };

    disko = {
      enable = true;
      # CHANGE ME: real disk. Prefer /dev/disk/by-id/... over /dev/sdX.
      device = "/dev/sda";
    };

    # Enable only after the one-time sops bootstrap (README "Private repos").
    secrets.enable = false;
  };
}
