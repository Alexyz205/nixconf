{
  config,
  inputs,
  lib,
  ...
}:
let
  system = "x86_64-linux";
  yubiPub = ../../config/ssh/id_ed25519_sk_rk_alexis-perso.pub;
  features = with config.flake.modules.nixos; [
    ssh
    users
    nix
    ca
  ];
in
{
  flake.nixosConfigurations.proxmox-vm = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      { nixpkgs.hostPlatform = system; }
      { nixpkgs.overlays = config.flake.modules.overlays; }
    ]
    ++ features
    ++ [
      ({ pkgs, modulesPath, ... }: {
        system.stateVersion = "26.05";

        modules.ca.enable = true;
        modules.users.userName = "alexis";

        users.users.alexis.openssh.authorizedKeys.keys = [
          (lib.trim (builtins.readFile yubiPub))
        ];

        security.sudo.wheelNeedsPassword = lib.mkForce false;

        services.qemuGuest.enable = true;

        services.cloud-init = {
          enable = true;
          network.enable = true;
        };

        environment.systemPackages = with pkgs; [
          vim
          git
          curl
          wget
        ];

        imports = [
          (modulesPath + "/profiles/qemu-guest.nix")
          (modulesPath + "/virtualisation/proxmox-image.nix")
        ];
      })
    ];
  };

  perSystem =
    { system, ... }:
    lib.mkIf (system == "x86_64-linux") {
      packages.proxmox-vm = config.flake.nixosConfigurations.proxmox-vm.config.system.build.VMA;
    };
}
