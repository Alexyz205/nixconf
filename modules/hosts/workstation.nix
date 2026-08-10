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
    niri
  ];
in
{
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules =
      [
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        inputs.home-manager.nixosModules.home-manager
      ]
      ++ features
      ++ [
        ({ pkgs, lib, ... }: {
          system.stateVersion = "24.11";

          networking.hostName = "workstation";
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

          environment.systemPackages = with pkgs; [
            firefox
            ghostty
          ];

          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
            jack.enable = true;
          };

          hardware = {
            enableRedistributableFirmware = true;
            bluetooth.enable = true;
            bluetooth.powerOnBoot = true;
            graphics.enable = true;
          };

          security.rtkit.enable = true;

          fonts.packages = with pkgs; [
            nerd-fonts.jetbrains-mono
          ];

          time.timeZone = "Europe/Paris";
          i18n.defaultLocale = "en_US.UTF-8";

          xdg.portal.enable = true;
          xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        })
      ];
  };
}