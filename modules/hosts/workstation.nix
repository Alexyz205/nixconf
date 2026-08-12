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
    zoxide
    lazyvim
    niri
    noctalia
  ];

  mkWorkstation = {
    hostName,
    diskDevice,
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
          }: let
            catppuccin = {
              accent = "mauve";
              cursorTheme = pkgs.catppuccin-cursors.mochaMauve;
              gtkTheme = pkgs.catppuccin-gtk.override {
                variant = "mocha";
                accents = ["mauve"];
                size = "standard";
              };
              iconTheme = pkgs.catppuccin-papirus-folders.override {
                flavor = "mocha";
                accent = "mauve";
              };
              sddmTheme = pkgs.catppuccin-sddm.override {
                flavor = "mocha";
                accent = "mauve";
              };
            };
          in {
            system.stateVersion = "24.11";
            networking.hostName = hostName;
            networking.firewall.allowedTCPPorts = [];
            disko.devices.disk.main.device = diskDevice;

            services.xserver.enable = true;
            services.displayManager.sddm = {
              enable = true;
              wayland.enable = true;
              theme = "catppuccin-mocha-mauve";
              extraPackages = [
                catppuccin.sddmTheme
                catppuccin.cursorTheme
              ];
            };
            services.displayManager.defaultSession = "niri";
            services.upower.enable = true;
            environment.systemPackages = with pkgs; [
              polkit_gnome
              catppuccin.gtkTheme
              catppuccin.iconTheme
              catppuccin.cursorTheme
              catppuccin.sddmTheme
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
              niri.enable = true;
              noctalia.enable = true;
            };

              home-manager = {
                useGlobalPkgs = true;
                extraSpecialArgs = {lazyvim = inputs.lazyvim;};
                users."alexis" = {
                  home.stateVersion = "24.11";
                  nix.package = lib.mkForce pkgs.nix;
                  gtk = {
                    enable = true;
                    cursorTheme = {
                      name = "catppuccin-mocha-mauve-cursors";
                      package = catppuccin.cursorTheme;
                      size = 24;
                    };
                    iconTheme = {
                      name = "Papirus-Dark";
                      package = catppuccin.iconTheme;
                    };
                    theme = {
                      name = "catppuccin-mocha-mauve-standard";
                      package = catppuccin.gtkTheme;
                    };
                    gtk4.theme = {
                      name = "catppuccin-mocha-mauve-standard";
                      package = catppuccin.gtkTheme;
                    };
                  };
                };
              };

            programs.firefox.enable = true;
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
    diskDevice = "/dev/disk/by-id/nvme-KBG40ZNS256G_NVMe_KIOXIA_256GB_Y1TPHIJFQXA3";
  };

  flake.nixosConfigurations.workstation-laptop = mkWorkstation {
    hostName = "laptop";
    diskDevice = "/dev/disk/by-id/REPLACE_WITH_THIS_MACHINE_DISK";
  };
}
