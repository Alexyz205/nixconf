{
  # ------------------------------------------------------------------
  # Flake: the entry point of a reproducible Nix project.
  #
  # - `inputs`: external dependencies (here: the nixpkgs package repo,
  #   pinned to a specific revision via flake.lock for reproducibility).
  # - `outputs`: what this flake produces (here: a NixOS configuration
  #   that builds a bootable ISO image).
  # ------------------------------------------------------------------

  description = "Custom NixOS installer/live ISO + secure target system";

  inputs = {
    # Use the unstable channel to get the latest packages/kernel.
    # Pin it later to a stable release (e.g. nixos-26.05) for production.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # disko: declarative partitioning/formatting.
    # Follows our nixpkgs to avoid dependency drift.
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # sops-nix: encrypted secrets (GitHub deploy key). Enable only after
    # the one-time bootstrap in README "Private repos" (see secrets.nix).
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, sops-nix }: let
    system = "x86_64-linux";
    # Absolute path to the nixpkgs NixOS modules, used to import the
    # official installer CD module.
    modulesPath = "${nixpkgs}/nixos/modules";
  in {
    nixosConfigurations = {
      # The live/installer ISO.
      #
      # Build it with:
      #   nix build .#nixosConfigurations.iso.config.system.build.isoImage
      # or, once nixos-rebuild is available:
      #   nixos-rebuild build-iso --flake .#iso
      iso = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Reuse the official minimal installer: live environment + console
          # installer (autologin nixos user, sshd, NetworkManager, ...).
          "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
          # Our own customizations on top of the installer.
          ./iso.nix
        ];
      };

      # The secure system the ISO installs.
      #
      # Filesystems + LUKS come from disko-config.nix, so no
      # hardware-configuration.nix is needed for mounting.
      # Install it with disko-install (see README):
      #   sudo nix run github:nix-community/disko/latest#disko-install -- \
      #     --flake .#default --disk main /dev/disk/by-id/...
      default = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          # Enable both lines after the sops bootstrap (README "Private repos"):
          # sops-nix.nixosModules.sops
          # ./secrets.nix
          ./disko-config.nix
          ./system.nix
        ];
      };
    };
  };
}
