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
    yubikey
    starship
    tmux
    bat
    eza
    lazygit
    yazi
    ghostty
    opencode
    zoxide
    lazyvim
    niri
    noctalia
    firefox
  ];

  mkWorkstation = {
    hostName,
    diskDevice ? "/dev/sda",
  }:
    inputs.nixpkgs.lib.nixosSystem {
      modules =
        [
          { nixpkgs.hostPlatform = system; }
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          inputs.stylix.nixosModules.stylix
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

            services.xserver.enable = true;
            services.greetd = {
              enable = true;
              settings = {
                default_session = {
                  command = "niri-session";
                  user = "alexis";
                };
              };
            };
            systemd.services.greetd.serviceConfig = {
              Type = "idle";
              StandardInput = "tty";
              StandardOutput = "tty";
              StandardError = "journal";
              TTYReset = true;
              TTYVHangup = true;
              TTYVTDisallocate = true;
            };

            stylix = {
              enable = true;
              autoEnable = true;
              base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
              polarity = "dark";
              cursor = {
                package = pkgs.catppuccin-cursors.mochaMauve;
                name = "catppuccin-mocha-mauve-cursors";
                size = 24;
              };
              fonts = {
                monospace = {
                  package = pkgs.nerd-fonts.jetbrains-mono;
                  name = "JetBrainsMono Nerd Font";
                };
              };
            };

            services.upower.enable = true;
            environment.systemPackages = with pkgs; [
              polkit_gnome
              base16-schemes
            ];

            modules = {
              users.userName = "alexis";
              users.hashedPasswordFile = config.sops.secrets.userPasswordHash.path;
              users.extraGroups = ["wheel" "networkmanager" "podman" "video"];
              packages = {
                basic = true;
                containers = true;
                security = true;
                devTools = true;
              };
              shell.enable = true;
              git.enable = true;
              yubikey.enable = true;
              yubikey.luksUnlock = true;
              yubikey.sudoAuth = true;
              starship.enable = true;
              tmux.enable = true;
              bat.enable = true;
              eza.enable = true;
              lazygit.enable = true;
              yazi.enable = true;
              zoxide.enable = true;
              lazyvim.enable = true;
              ghostty.enable = true;
              opencode.enable = true;
              niri.enable = true;
              noctalia.enable = true;
              firefox.enable = true;
            };

              home-manager = {
                useGlobalPkgs = true;
                extraSpecialArgs = {lazyvim = inputs.lazyvim;};
                users."alexis" = {
                  home.stateVersion = "24.11";
                  nix.package = lib.mkForce pkgs.nix;
                  services.cliphist = {
                    enable = true;
                    allowImages = true;
                  };
                };
              };

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
in {
  flake.nixosConfigurations.workstation = mkWorkstation {
    hostName = "workstation";
  };
}
