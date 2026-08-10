{
  config,
  inputs,
  ...
}:
let
  system = "x86_64-linux";
  devtools = config.flake.modules.homeManager.devtools;
  features = with config.flake.modules.nixos; [
    boot
    network
    security
    ssh
    podman
    nix
    users
    shell
    packages
    disko
    secrets
  ];
in
{
  flake.nixosConfigurations.server = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules =
      [
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        inputs.home-manager.nixosModules.home-manager
      ]
      ++ features
      ++ [
        ({ lib, ... }: {
          system.stateVersion = "24.11";

          networking.hostName = "server";
          networking.firewall.allowedTCPPorts = [ ];

          disko.devices.disk.main.device = "/dev/sda";

          modules = {
            users.userName = "alexis.pigeon";
            packages = {
              basic = true;
              containers = true;
            };
          };

          home-manager = {
            useGlobalPkgs = true;
            extraSpecialArgs = {
              lazyvim = inputs.lazyvim;
            };
            users."alexis.pigeon" = {
              home.stateVersion = "24.11";
              imports = [ devtools ];
            };
          };
        })
      ];
  };
}