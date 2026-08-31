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
    containers
    disko
    sops
    git
    yubikey
    devenv
    starship
    tmux
    bat
    eza
    lazygit
    yazi
    btop
    ghostty
    opencode
    zoxide
    lazyvim
    tv
    niri
    noctalia
    hiddenApps
    brave
    claude
    discord
    steam
    youtubeMusic
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

            nixpkgs.config.allowUnfreePredicate = pkg:
              builtins.elem (lib.getName pkg) [
                "brave"
                "steam"
                "steam-unwrapped"
                "claude-desktop"
                "vesktop"
                "nvidia-x11"
                "nvidia-settings"
              ];
            disko.devices.disk.main.device = diskDevice;

            services.xserver.enable = true;
            # Required for hardware.nvidia to actually activate: the module is
            # gated on "nvidia" being listed here (nvidia.nix: nvidiaEnabled).
            services.xserver.videoDrivers = ["nvidia"];
            # Disable TTS service: the graphical-desktop default enables
            # speech-dispatcher (pulls mbrola/espeak/flite, ~890MB, unused here).
            services.speechd.enable = false;
            # Only the declared JetBrains Mono + emoji fonts are used, so skip
            # the default CJK/unifont package set (~170MB).
            fonts.enableDefaultPackages = false;
            services.greetd = {
              enable = true;
              settings = {
                default_session = {
                  command = "niri-session";
                  user = config.modules.users.userName;
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
              # Disabled to avoid pulling inkscape as a build dependency (stylix uses it for icon recoloring)
              overlays.enable = false;
              icons.enable = false;
              cursor = {
                package = pkgs.catppuccin-cursors.mochaMauve;
                name = "catppuccin-mocha-mauve-cursors";
                size = 24;
              };
              fonts = rec {
                monospace = {
                  package = pkgs.nerd-fonts.jetbrains-mono;
                  name = "JetBrainsMono Nerd Font";
                };
                sansSerif = monospace;
                serif = monospace;
              };
            };

            services.upower.enable = true;
            environment.systemPackages = with pkgs; [
              polkit_gnome
              base16-schemes
            ];

            modules = {
              users.extraGroups = ["wheel" "networkmanager" "podman" "video"];
              packages = {
                basic = true;
                security = true;
                devTools = true;
                desktop = true;
              };
              containers.enable = true;
              shell.enable = true;
              git.enable = true;
              yubikey.enable = true;
              yubikey.luksUnlock = true;
              yubikey.sudoAuth = true;
              starship.enable = true;
              tmux.enable = true;
              bat.enable = true;
              eza.enable = true;
              btop.enable = true;
              lazygit.enable = true;
              yazi.enable = true;
              zoxide.enable = true;
              lazyvim.enable = true;
              tv.enable = true;
              ghostty.enable = true;
              opencode.enable = true;
              devenv.enable = true;
              niri.enable = true;
              noctalia.enable = true;
              hiddenApps.enable = true;
              brave.enable = true;
              claude.enable = true;
              discord.enable = true;
              steam.enable = true;
              youtubeMusic.enable = true;
            };

              home-manager = {
                useGlobalPkgs = true;
                extraSpecialArgs = {lazyvim = inputs.lazyvim;};
                users.${config.modules.users.userName} = {
                  home.stateVersion = "24.11";
                  nix.package = lib.mkForce pkgs.nix;
                  services.cliphist = {
                    enable = true;
                    allowImages = true;
                  };
                  # Stylix targets for apps not present in this repo/configuration.
                  # AutoEnable would otherwise generate theme config for them.
                  # btop is themed explicitly by modules/shell/btop.nix, so Stylix's
                  # auto-enabled btop target must be disabled: its generated "stylix"
                  # theme conflicts with the repo's color_theme = "catppuccin_mocha".
                  stylix.targets = {
                    ghostty.enable = false;
                    btop.enable = false;
                    blender.enable = false;
                    forge.enable = false;
                    gdu.enable = false;
                    gedit.enable = false;
                    gnome.enable = false;
                    gnome-text-editor.enable = false;
                    gtksourceview.enable = false;
                    kde.enable = false;
                    rofi.enable = false;
                    vencord.enable = false;
                    nixcord.enable = false;
                    qt.enable = false;
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
              # Unconditional: enables the NVIDIA driver whenever an NVIDIA GPU
              # is present; harmless (module never binds) on non-NVIDIA hardware.
              nvidia = {
                modesetting.enable = true;
                open = true;
              };
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
