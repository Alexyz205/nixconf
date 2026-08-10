# Flake: the entry point of a reproducible Nix project.
#
# Structure (video: "Modularize NixOS and Home Manager"):
#   hosts/<host>/          one directory per machine, config.nix + hardware
#   nixos-modules/         shared toggleable modules (see default.nix)
#
# Each host imports the shared module library and only enables the modules
# it needs via `modules.<name>.enable` flags.
{
  description = "Modular NixOS configuration: hosts + toggleable shared modules";

  inputs = {
    # Use the unstable channel to get the latest packages/kernel.
    # Pin it later to a stable release (e.g. nixos-26.05) for production.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # disko: declarative partitioning/formatting.
    # Follows our nixpkgs to avoid dependency drift.
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # sops-nix: encrypted secrets (GitHub deploy key). Hosts opt in via
    # modules.secrets.enable AFTER the one-time bootstrap (README).
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, sops-nix }: let
    system = "x86_64-linux";
    # Absolute path to the nixpkgs NixOS modules, used to import the
    # official installer CD module for the ISO.
    modulesPath = "${nixpkgs}/nixos/modules";

    # Build a real host: always gets disko + sops-nix modules plus the
    # shared module library and the host's own config.
    mkHost = host: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        # Shared, toggleable module library (imports all modules; hosts
        # enable the ones they need).
        ./nixos-modules
        ./hosts/${host}/configuration.nix
      ];
    };

    # Build a live/installer ISO for one purpose (not a real host).
    # Each purpose has its own file under hosts/iso/<purpose>.nix and a
    # distinct `isoImage.edition` so the built image is identifiable.
    mkIso = purpose: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Reuse the official minimal installer: live environment + console
        # installer (autologin nixos user, sshd, NetworkManager, ...).
        "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
        # Our customizations on top of the installer.
        ./hosts/iso/${purpose}.nix
      ];
    };
  in {
    nixosConfigurations = {
      # Live/installer ISO for a default Proxmox VM.
      #
      # Build it with:
      #   nix build .#nixosConfigurations.iso-proxmox.config.system.build.isoImage
      # or, once nixos-rebuild is available:
      #   nixos-rebuild build-iso --flake .#iso-proxmox
      # Add another ISO for a different purpose via mkIso (e.g.
      # `iso-rescue = mkIso "rescue";`).
      iso-proxmox = mkIso "proxmox";

      # Real machines. Install with disko-install (see README):
      #   sudo nix run github:nix-community/disko/latest#disko-install -- \
      #     --flake .#default --disk main /dev/disk/by-id/...
      default = mkHost "default";
      workstation = mkHost "workstation";
    };
  };
}
