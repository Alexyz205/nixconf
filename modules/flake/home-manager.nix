{
  inputs,
  config,
  lib,
  ...
}: {
  flake.homeConfigurations."alexis.pigeon" =
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
        lazyvim = inputs.lazyvim;
      };
      modules = [
        ./../home/packages.nix
      ];
    };
}
