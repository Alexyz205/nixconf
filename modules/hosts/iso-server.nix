{
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.iso-server = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ({pkgs, ...}: {
        isoImage.edition = "server";

        environment.systemPackages =
          (import ../../packages.nix {inherit pkgs lib;}).home.packages;

        system.stateVersion = "24.11";
      })
    ];
  };
}
