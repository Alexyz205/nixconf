{
  config,
  inputs,
  ...
}: let
  system = "x86_64-linux";
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
    git
    starship
    tmux
    bat
    eza
    lazygit
    yazi
    zoxide
  ];
in {
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
        ({
          pkgs,
          lib,
          ...
        }: {
          system.stateVersion = "24.11";
          networking.hostName = "server";
          networking.firewall.allowedTCPPorts = [];
          disko.devices.disk.main.device = "/dev/sda";

          modules = {
            users.userName = "alexis.pigeon";
            packages = {
              basic = true;
              containers = true;
              devTools = true;
            };
            shell.enable = true;
            git.enable = true;
            starship.enable = true;
            tmux.enable = true;
            bat.enable = true;
            eza.enable = true;
            lazygit.enable = true;
            yazi.enable = true;
            zoxide.enable = true;
          };

          home-manager = {
            useGlobalPkgs = true;
            extraSpecialArgs = {lazyvim = inputs.lazyvim;};
            users."alexis.pigeon" = {
              home.stateVersion = "24.11";
              nix.package = lib.mkForce pkgs.nix;
            };
          };
        })
      ];
  };
}
