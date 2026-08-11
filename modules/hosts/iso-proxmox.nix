{inputs, ...}: {
  flake.nixosConfigurations.iso-proxmox = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ({pkgs, ...}: {
        isoImage.edition = "proxmox";

        boot.kernelPackages = pkgs.linuxPackages_latest;
        boot.supportedFilesystems = ["btrfs" "xfs" "ntfs" "cifs"];

        services.qemuGuest.enable = true;

        environment.systemPackages = with pkgs; [
          curl
          wget
          htop
          tmux
          ripgrep
          fd
          vim
          nix-tree
          nix-output-monitor
        ];

        boot.zfs.forceImportRoot = false;
        system.stateVersion = "24.11";
      })
    ];
  };
}
