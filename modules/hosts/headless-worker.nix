{
  config,
  inputs,
  lib,
  ...
}: let
  system = "x86_64-linux";
  yubiPub = ../config/ssh/id_ed25519_sk_rk_alexis-perso.pub;
  features = with config.flake.modules.nixos; [
    boot
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
    opencode
    zoxide
    lazyvim
  ];

  mkServer = {
    hostName,
    diskDevice ? "/dev/sda",
  }:
    inputs.nixpkgs.lib.nixosSystem {
      modules =
        [
          { nixpkgs.hostPlatform = system; }
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          inputs.home-manager.nixosModules.home-manager
        ]
        ++ features
        ++ [
          ({
            config,
            pkgs,
            lib,
            ...
          }: {
            system.stateVersion = "24.11";
            networking.hostName = hostName;
            networking.firewall.allowedTCPPorts = [];
            disko.devices.disk.main.device = diskDevice;

            # systemd-networkd instead of NetworkManager
            networking.networkmanager.enable = lib.mkForce false;
            systemd.network = {
              enable = true;
              networks."50-dhcp" = {
                matchConfig.Name = "en*";
                networkConfig.DHCP = "yes";
              };
            };
            services.resolved.enable = true;

            # SSH key from existing YubiKey pub (no hardware needed at runtime)
            modules.users.userName = "alexis";
            modules.users.hashedPasswordFile = config.sops.secrets.userPasswordHash.path;
            modules.users.extraGroups = ["wheel" "podman"];
            users.users.alexis.openssh.authorizedKeys.keys = [
              (lib.trim (builtins.readFile yubiPub))
            ];

            # Packages
            modules.packages = {
              basic = true;
              containers = true;
              security = true;
              devTools = true;
            };
            modules.shell.enable = true;
            modules.git.enable = true;
            modules.starship.enable = true;
            modules.tmux.enable = true;
            modules.bat.enable = true;
            modules.eza.enable = true;
            modules.lazygit.enable = true;
            modules.yazi.enable = true;
            modules.zoxide.enable = true;
            modules.lazyvim.enable = true;
            modules.opencode.enable = true;

            home-manager = {
              useGlobalPkgs = true;
              extraSpecialArgs = {lazyvim = inputs.lazyvim;};
              users."alexis" = {
                home.stateVersion = "24.11";
                nix.package = lib.mkForce pkgs.nix;
              };
            };

            # Server optimizations
            nix.gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 30d";
            };
            boot.kernelParams = ["quiet"];

            hardware.enableRedistributableFirmware = true;
            time.timeZone = "Europe/Paris";
            i18n.defaultLocale = "en_US.UTF-8";
          })
        ];
    };
in {
  flake.nixosConfigurations.headless-worker = mkServer {
    hostName = "headless-worker";
  };
}
