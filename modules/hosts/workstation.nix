{
  config,
  inputs,
  ...
}:
let
  system = "x86_64-linux";
  features = config.nixconf.nixosFeatures.desktop;
  mkHostCommon = config.nixconf.mkHostCommon;
  palette = import ../../config/theme/catppuccin-mocha.nix;

  mkWorkstation =
    {
      hostName,
      diskDevice ? "/dev/sda",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.hostPlatform = system; }
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        inputs.stylix.nixosModules.stylix
        inputs.home-manager.nixosModules.home-manager
        (mkHostCommon {
          inherit hostName;
          stateVersion = "26.05";
        })
      ]
      ++ features
      ++ [
        config.nixconf.modules.nixos.networkTuning
        config.nixconf.modules.nixos.moonshine
        (
          {
            config,
            pkgs,
            lib,
            ...
          }:
          {
            nixpkgs.config.allowUnfreePredicate =
              pkg:
              builtins.elem (lib.getName pkg) [
                "brave"
                "steam"
                "steam-unwrapped"
                "claude-desktop"
                "vesktop"
                "nvidia-x11"
                "nvidia-settings"
              ]
              || builtins.any (license: license == lib.licenses.nvidiaCudaRedist) (
                lib.lists.toList (pkg.meta.license or [ ])
              );
            disko.devices.disk.main.device = diskDevice;

            services = {
              xserver = {
                enable = true;
                # Required for hardware.nvidia to actually activate: the module is
                # gated on "nvidia" being listed here (nvidia.nix: nvidiaEnabled).
                videoDrivers = [ "nvidia" ];
              };
              # Disable TTS service: the graphical-desktop default enables
              # speech-dispatcher (pulls mbrola/espeak/flite, ~890MB, unused here).
              speechd.enable = false;
              greetd = {
                enable = true;
                # Auto-login at boot; after a logout (niri exits) greetd falls
                # back to the login screen wired below (default_session set by
                # the displayManager.noctalia-greeter module).
                settings.initial_session = {
                  command = "niri-session";
                  user = config.modules.users.userName;
                };
              };
              # Login/logout screen: shown whenever the niri session ends. The
              # module points greetd's default_session at the greeter, which
              # picks up the "Niri" wayland session from sessionPackages.
              displayManager.noctalia-greeter = {
                enable = true;
                settings = {
                  session.default = "Niri";
                  user.default = config.modules.users.userName;
                  keyboard.layout = "us";
                  cursor.size = 24;
                  appearance = {
                    scheme = "Synced";
                    theme_mode = "dark";
                    # Same wallpaper as the desktop (niri/swaybg) and lock
                    # screen (stylix -> hyprlock), so login matches both.
                    wallpaper = {
                      path = config.stylix.image;
                      fill_mode = "crop";
                    };
                    palette = {
                      primary = palette.mauve;
                      on_primary = palette.base;
                      secondary = palette.subtext0;
                      on_secondary = palette.base;
                      tertiary = palette.lavender;
                      on_tertiary = palette.base;
                      error = palette.red;
                      on_error = palette.base;
                      surface = palette.base;
                      on_surface = palette.text;
                      surface_variant = palette.surface0;
                      on_surface_variant = palette.subtext0;
                      outline = palette.overlay1;
                      shadow = "#000000";
                      hover = palette.mauve;
                      on_hover = palette.base;
                    };
                  };
                };
                cursorTheme = {
                  package = pkgs.catppuccin-cursors.mochaMauve;
                  name = "catppuccin-mocha-mauve-cursors";
                };
              };
              upower.enable = true;
              pipewire = {
                enable = true;
                alsa.enable = true;
                pulse.enable = true;
              };
            };
            # Only the declared JetBrains Mono + emoji fonts are used, so skip
            # the default CJK/unifont package set (~170MB).
            fonts.enableDefaultPackages = false;

            stylix = {
              enable = true;
              autoEnable = true;
              # Same palette as everything else (config/theme/catppuccin-mocha.nix),
              # inlined as a base16 scheme so stylix consumes the single source
              # instead of the base16-schemes package.
              base16Scheme = palette.base16 // {
                scheme = "catppuccin-mocha";
              };
              polarity = "dark";
              # Same catppuccin-mocha wallpaper niri shows; used by wallpaper-aware
              # stylix targets (e.g. hyprlock's lock-screen background).
              image = "${pkgs.nixos-artwork.wallpapers.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png";
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

            environment.systemPackages = with pkgs; [
              polkit_gnome
            ];

            modules = {
              # Infrastructure (base + server tiers)
              nix.enable = true;
              users.enable = true;
              security.enable = true;
              ssh.enable = true;
              boot.enable = true;
              disko.enable = true;
              sops.enable = true;
              podman.enable = true;
              network.enable = true;
              # BBR + fq + larger buffers, and disable EEE on the Intel I226-V
              # (igc) NIC, which otherwise flaps the 2.5GbE link.
              networkTuning = {
                enable = true;
                interface = "enp4s0";
              };
              users.extraGroups = [
                "wheel"
                "networkmanager"
                "podman"
                "video"
              ];
              packages = {
                basic = true;
                security = true;
                devTools = true;
                desktop = true;
              };
              containers.enable = true;
              nextcloud.enable = true;
              sops = {
                # No USB port on this machine: decrypt with the software age
                # key instead of the YubiKey identity.
                useYubikey = false;
                ageKeyFile = "/home/alexis/.config/sops/age/keys.txt";
              };
              shell.enable = true;
              git.enable = true;
              bitwarden = {
                enable = true;
                desktop = true;
                autostart = false;
              };
              yubikey = {
                enable = true;
                luksUnlock = true;
                # No USB port for the YubiKey here: pam_u2f would prompt for a
                # FIDO authenticator on every sudo with nothing to insert.
                sudoAuth = false;
              };
              starship.enable = true;
              tmux.enable = true;
              bat.enable = true;
              eza.enable = true;
              diskusage.enable = true;
              btop.enable = true;
              # RTX 5070: enable btop's CUDA GPU-usage support.
              btop.cudaSupport = true;
              lazygit.enable = true;
              yazi.enable = true;
              zoxide.enable = true;
              lazyvim.enable = true;
              tv.enable = true;
              ghostty.enable = true;
              opencode = {
                enable = true;
                mcp = {
                  blender.enable = true;
                  freecad.enable = true;
                };
              };
              devenv.enable = true;
              niri = {
                enable = true;
                # Match the greeter (below) and lock screen (stylix -> hyprlock).
                wallpaper = config.stylix.image;
                settings = {
                  # The MSI MAG401QR reports 60 Hz as its preferred mode, so force
                  # the 155 Hz mode. Must match `niri msg outputs` down to three
                  # decimals.
                  outputs."DP-3".mode = "3440x1440@155.000";
                  # NVIDIA: force a full modeset on resume. Without this, waking
                  # from suspend leaves niri's DRM output corrupted and the screen
                  # freezes/greys on the first redraw after unlock.
                  debug."force-disable-connectors-on-resume" = _: { };
                };
              };
              noctalia.enable = true;
              lock.enable = true;
              hiddenApps.enable = true;
              brave.enable = true;
              claude.enable = true;
              discord.enable = true;
              steam.enable = true;
              heroic.enable = true;
              prism.enable = true;
              controller.enable = true;
              # Headless Moonlight host for the Xbox: each stream gets its own
              # isolated 16:9 compositor (host desktop unaffected). LAN-only on
              # the wired NIC because GameStream is not fully encrypted.
              moonshine = {
                enable = true;
                firewallInterfaces = [ "enp4s0" ];
              };
              thunderbird = {
                enable = true;
                email = "alexis@alexyz.org";
                realName = "Alexis Pigeon";
              };
              youtubeMusic.enable = true;
              cap.enable = true;
              gitlab.enable = true;
              swayimg.enable = true;
              photocraft.enable = true;
              lightcraft.enable = true;
              pdfcraft.enable = true;
              filmcraft.enable = true;
              wordcraft.enable = true;
              gridcraft.enable = true;
              cadcraft.enable = true;
              blender = {
                enable = true;
                cudaSupport = true;
              };
              freecad.enable = true;
              deckcraft.enable = true;
              soundcraft.enable = true;
            };

            home-manager.users.${config.modules.users.userName} = {
              # Same software age key as the NixOS side (see modules.sops above):
              # decrypts GITHUB_TOKEN and the sec/sece aliases on this host.
              modules.sops.ageKeyFile = "/home/alexis/.config/sops/age/keys.txt";
              modules.sops.useYubikey = false;
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

            hardware = {
              bluetooth.enable = true;
              graphics.enable = true;
              # Unconditional: enables the NVIDIA driver whenever an NVIDIA GPU
              # is present; harmless (module never binds) on non-NVIDIA hardware.
              nvidia = {
                # RTX 5070 (Blackwell) on the new-feature branch (615.x) instead
                # of production (595.x). Roll back by deleting this line and
                # rebuilding + rebooting; the previous system generation stays in
                # the boot menu either way.
                package = config.boot.kernelPackages.nvidiaPackages.latest;
                modesetting.enable = true;
                open = true;
                # Reinitialise the GPU on resume; without this the driver never
                # recovers from suspend and the screen freezes on the first
                # redraw after unlocking (grey screen on the next wake).
                powerManagement.enable = true;
              };
            };
            security.rtkit.enable = true;
            fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
            xdg.portal.enable = true;
            xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
          }
        )
      ];
    };
in
{
  flake-file.inputs.stylix = {
    url = "github:danth/stylix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.nixosConfigurations.workstation = mkWorkstation {
    hostName = "workstation";
  };
}
