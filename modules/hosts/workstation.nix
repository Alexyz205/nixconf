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
    ghostty
    zoxide
    lazyvim
    niri
    noctalia
  ];
in {
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
        ({
          pkgs,
          lib,
          ...
        }: {
          system.stateVersion = "24.11";
          networking.hostName = "workstation";
          networking.firewall.allowedTCPPorts = [];
          disko.devices.disk.main.device = "/dev/sda";

          modules = {
            users.userName = "alexis";
            packages = {
              basic = true;
              containers = true;
              security = true;
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
            lazyvim.enable = true;
            ghostty.enable = true;
            niri.enable = true;
            noctalia.enable = true;
          };

          home-manager = {
            useGlobalPkgs = true;
            extraSpecialArgs = {lazyvim = inputs.lazyvim;};
            users."alexis" = {
              home.stateVersion = "24.11";
              nix.package = lib.mkForce pkgs.nix;
            };
          };

          environment.systemPackages = with pkgs; [firefox ghostty];
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };
          hardware = {
            enableRedistributableFirmware = true;
            bluetooth.enable = true;
            graphics.enable = true;
          };
          security.rtkit.enable = true;
          fonts.packages = with pkgs; [nerd-fonts.jetbrains-mono];
          time.timeZone = "Europe/Paris";
          i18n.defaultLocale = "en_US.UTF-8";
          xdg.portal.enable = true;
          xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
        })
      ];
  };
}
