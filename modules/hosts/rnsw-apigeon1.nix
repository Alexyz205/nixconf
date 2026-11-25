{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  system = "x86_64-linux";
  flakeConfig = config;
  features = config.nixconf.nixosFeatures.desktop;
  mkHostCommon = config.nixconf.mkHostCommon;
  palette = import ../../config/theme/catppuccin-mocha.nix;
  corpUser = "alexis.pigeon";
  localUser = "alexis";
  # Addressed by serial, never by /dev/nvmeXnY: the kernel swaps those names
  # between boots on this machine, and an earlier run formatted the wrong disk
  # because of it. `lsblk -o NAME,SIZE,MODEL,SERIAL` prints the serials.
  #   WDC PC SN810 2 TB     -> system: ESP + LUKS + btrfs
  #   SK hynix PC811 512 GB -> data: LUKS + btrfs at /data
  nixosDisk = "/dev/disk/by-id/nvme-PC_SN810_NVMe_WDC_2048GB_21284T443808";
  dataDisk = "/dev/disk/by-id/nvme-PC811_SK_hynix_512GB____AYD2N030211302R39";

  stylixTargets = {
    bat.enable = false;
    ghostty.enable = false;
    starship.enable = false;
    yazi.enable = false;
    lazygit.enable = false;
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
    wayprompt.enable = false;
  };
in
{
  flake.nixosConfigurations.rnsw-apigeon1 = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      { nixpkgs.hostPlatform = system; }
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops
      inputs.stylix.nixosModules.stylix
      inputs.home-manager.nixosModules.home-manager
      (mkHostCommon {
        hostName = "RNSW-APIGEON1";
        stateVersion = "26.05";
      })
    ]
    ++ features
    ++ [
      config.nixconf.modules.nixos.networkTuning
      config.nixconf.modules.nixos.corpAuth
      config.nixconf.modules.nixos.corpNas
      config.nixconf.modules.nixos.sentinelone
      config.nixconf.modules.nixos.nessusAgent
      config.nixconf.modules.nixos.ollama
      (
        {
          config,
          pkgs,
          ...
        }:
        let
          # ~/.face is what AccountsService/the greeter use when no icon is set.
          mkAvatar =
            name: initials: color:
            pkgs.runCommand "avatar-${name}" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
              mkdir -p "$out"
              magick -size 256x256 xc:'#1e1e2e' \
                -fill '${color}' \
                -font ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf \
                -pointsize ${if builtins.stringLength initials > 1 then "100" else "120"} \
                -gravity center -annotate +0+0 '${initials}' "$out/avatar.png"
            '';
        in
        {
          nixpkgs.config.allowUnfreePredicate = flakeConfig.nixconf.allowUnfreePredicate;

          # The disko module owns the main layout (1 GiB ESP + LUKS/btrfs); the
          # host points it at the 2 TB disk and sizes the swapfile.
          disko.devices.disk.main = {
            device = nixosDisk;
            content.partitions.luks.content.content.subvolumes."/swap".swap.swapfile.size = lib.mkForce "64G";
          };

          # Second NVMe: whole-disk LUKS (same passphrase as the system volume,
          # so the boot prompt asks twice) with one btrfs subvolume at /data.
          # Model weights and bulk data live here, keeping /persistent lean.
          disko.devices.disk.data = {
            type = "disk";
            device = dataDisk;
            content = {
              type = "gpt";
              partitions.data = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "data-crypt";
                  settings.allowDiscards = true;
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    subvolumes."/data" = {
                      mountpoint = "/data";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                  };
                };
              };
            };
          };

          # Hibernation resumes from the swapfile inside the unlocked LUKS
          # container. systemd-hibernate records the btrfs swapfile offset in the
          # HibernateLocation EFI variable, so no static resume_offset is needed.
          boot.resumeDevice = "/dev/mapper/crypted";

          services = {
            xserver = {
              enable = true;
              videoDrivers = [ "nvidia" ];
              # xserver pulls xterm into systemPackages; Ghostty is the terminal.
              excludePackages = [ pkgs.xterm ];
            };
            speechd.enable = false;
            greetd = {
              enable = true;
              settings.initial_session = {
                command = "niri-session";
                # alexis.pigeon is the daily work account; alexis stays available
                # from the greeter (and via sudo) for rebuilds.
                user = corpUser;
              };
            };
            displayManager.noctalia-greeter = {
              enable = true;
              settings = {
                session.default = "Niri";
                user.default = corpUser;
                keyboard.layout = "us";
                cursor.size = 24;
                # The panel advertises 2560x1080 as preferred; force the same
                # 5K2K timing the niri session uses.
                output = {
                  name = "DP-4";
                  use_synced_settings = false;
                  width = 5120;
                  height = 2160;
                  refresh_rate = 59.985;
                  scale = 1.5;
                };
                appearance = {
                  scheme = "Synced";
                  theme_mode = "dark";
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
            udisks2.enable = true;
            fwupd.enable = true;
            pipewire = {
              enable = true;
              alsa.enable = true;
              pulse.enable = true;
            };
          };

          fonts.enableDefaultPackages = false;

          stylix = {
            enable = true;
            autoEnable = true;
            base16Scheme = palette.base16 // {
              scheme = "catppuccin-mocha";
            };
            polarity = "dark";
            image = "${pkgs.nixos-artwork.wallpapers.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png";
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
            wl-clipboard
          ];

          modules = {
            # Work machine: gaming stays off, creative/media apps are on but
            # mail lives in Outlook.
            bitwarden.enable = false;
            claude.enable = false;
            discord.enable = false;
            steam.enable = false;
            heroic.enable = false;
            prism.enable = false;
            controller.enable = false;
            thunderbird.enable = false;
            youtubeMusic.enable = true;
            # Both accounts commit with the work identity by default; the
            # personal includeIf in modules.git overrides it under
            # ~/repos/personal/.
            git = {
              userName = "Alexis Pigeon";
              userEmail = "alexis.pigeon@take2games.com";
            };
            gitlab.hosts = [ "git.dxyz.pro" ];
            # Blender is the official build with precompiled Cycles CUDA/OptiX.
            blender.enable = true;
            freecad.enable = true;
            # Personal WebDAV mount (alexyz); its secrets are not in corp.yaml.
            nextcloud.enable = false;
            # Okta extension for the browser (the NixOS option feeds the
            # injected home-manager config; the local user does not import the
            # home-manager chromium module).
            chromium.okta = true;
            # Corporate startup pages, enforced through system policy so a
            # restored session cannot hide them. Only this host opts in.
            chromium.startupUrls = [
              "https://app.slack.com/client/"
              "https://outlook.cloud.microsoft/mail/"
              "https://git.dxyz.pro/"
            ];

            packages = {
              basic = true;
              security = true;
              devTools = true;
              desktop = true;
            };

            users = {
              extraGroups = [
                "wheel"
                "networkmanager"
                "podman"
                "video"
                "dialout"
              ];
              # Both interactive accounts get the same feature-module wiring;
              # alexis.pigeon is the daily driver, alexis the local admin.
              homeUsers = [
                localUser
                corpUser
              ];
            };
            # Key-only sshd (see modules.ssh): the YubiKey resident key is the
            # only remote admin identity (wired by modules.yubikey below).
            # The LDAP account also needs a local passwd entry: home-manager
            # requires users.users.<name>, and the AD-mapped ids are stable, so
            # declaring them keeps /etc/passwd, home ownership and SSSD in sync.
            # Verify with `id alexis.pigeon` on the enrolled Ubuntu laptop.
            corpAuth.accounts = {
              "${corpUser}" = 1755687199;
            };
            # /etc/shadow is rebuilt every boot, so the hash lives on the
            # persistent volume (created by the install runbook).
            users.hashedPasswordFile = "/persistent/etc/alexis.hash";

            sops = {
              # Software age key in the local admin's home: boots without a
              # YubiKey tap. This host only decrypts corp.yaml (its age key is
              # not a recipient of secrets.yaml), so modules that only use
              # secrets.yaml are not enabled here.
              useYubikey = false;
              interactiveYubikey = true;
              ageKeyFile = "/home/${localUser}/.config/sops/age/keys.txt";
              secretsFile = ../../secrets/corp.yaml;
            };

            # YubiKey for SSH only: disk and sudo stay password-only.
            yubikey = {
              enable = true;
              sshKey = true;
              luksUnlock = false;
              sudoAuth = false;
            };

            btop.cudaSupport = true;

            # Both accounts get the themed bar; niri itself is the same wrapped
            # system package for every user.
            noctalia.users = [
              localUser
              corpUser
            ];

            niri = {
              wallpaper = config.stylix.image;
              settings = {
                "screenshot-path" = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
                # The U4021QW advertises 2560x1080 as its preferred mode over
                # this DP link, so force the native 5K2K timing. Must match
                # `niri msg outputs` down to three decimals.
                outputs."DP-4" = {
                  mode = "5120x2160@59.985";
                  scale = 1.5;
                };
                # Left-handed mouse: swap primary/secondary buttons.
                input.mouse.left-handed = _: { };
              };
            };

            impermanence = {
              enable = true;
              directories = [
                "/var/log"
                "/var/lib/nixos"
                "/var/lib/systemd"
                "/etc/NetworkManager/system-connections"
                "/var/lib/NetworkManager"
                "/var/lib/bluetooth"
                "/var/lib/containers"
                "/var/lib/sbctl"
                "/var/lib/fwupd"
                # Offline AD login after a reboot without network.
                "/var/lib/sss"
                "/var/lib/sentinelone"
                "/var/lib/nessus_agent"
              ];
              # The module appends every sshd host key automatically; only the
              # machine-id needs listing here.
              files = [ "/etc/machine-id" ];
              userDirectories = [ ];
            };

            secureBoot = {
              enable = true;
              autoGenerateKeys = true;
              autoEnrollKeys = true;
              autoReboot = false;
            };

            corpAuth.enable = true;
            corpNas = {
              enable = true;
              # AD-mapped ids: the work session (alexis.pigeon) owns the shares,
              # the local admin reaches them with sudo.
              uid = 1755687199;
              gid = 1755600513;
              shares = {
                public = {
                  source = "//10.113.8.28/Public";
                  mountPoint = "/mnt/qraid";
                };
                # Personal studio share: authenticated as the AD user, not the
                # shared service account Public uses.
                studio_d = {
                  source = "//10.113.8.28/rnsw_studio_d";
                  mountPoint = "/mnt/studio_d";
                  usernameSecret = "corp/studio_username";
                  passwordSecret = "corp/studio_password";
                };
              };
            };
            # Built from the proprietary debs the T2 Artifactory serves (see
            # docs/rnsw-apigeon1.md).
            sentinelone.enable = true;
            nessusAgent.enable = true;
            ollama.enable = true;
          };

          # Same right the Ubuntu enrollment script grants the AD account
          # (usermod -a -G sudo); the AD group rules stay in place too.
          users.users.${corpUser} = {
            extraGroups = [ "wheel" ];
            # The greeter runs as the unprivileged `greeter` user and has to
            # traverse the home to load ~/.face. 0711 = traverse, no listing.
            homeMode = "0711";
          };
          users.users.${localUser}.homeMode = "0711";

          # Models are tens of GiB: keep them on the second NVMe instead of the
          # system volume.
          services.ollama = {
            home = "/data/ollama";
            modelsDir = "/data/ollama/models";
          };

          hardware = {
            bluetooth.enable = true;
            graphics.enable = true;
            nvidia = {
              modesetting.enable = true;
              open = true;
              powerManagement.enable = true;
              # Linux R620 branch (620.73.04). nixpkgs tops out at 615.78.08, so
              # the driver is packaged here; settings and persistenced stay on
              # the 615 tag they are released under.
              package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
                version = "620.73.04";
                url = "https://download.nvidia.com/XFree86/Linux-x86_64/620.73.04/NVIDIA-Linux-x86_64-620.73.04.run";
                sha256_64bit = "sha256-tfLi1dqENbMlOTBAFbib9+si/grsjNaQW3puip+bjxs=";
                openSha256 = "sha256-+GPU2bXC/QWZTt0eH3dTvI0bMAta1GCdU2WFI4E4LWE=";
                settingsVersion = "615.78.08";
                settingsSha256 = "sha256-inDRpG02sdDgHmlqgu/DsgK8OFdOt1fZIYyXdhlGC/c=";
                persistencedVersion = "615.78.08";
                persistencedSha256 = "sha256-RzeR6Ldct6MUxjnXRyThdh5Y3jjMehTVg85MtwuWNX4=";
              };
            };
          };
          security.rtkit.enable = true;
          fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
          xdg.portal.enable = true;
          xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

          home-manager = {
            extraSpecialArgs.self = self;
            # The corporate account keeps a local passwd entry (modules.corpAuth
            # .accounts) so home-manager can activate it at boot like any other
            # user; authentication still goes through SSSD/Kerberos.
            users.${corpUser} = {
              # Same modules and settings as the local admin: the host adds this
              # account to modules.users.homeUsers, so every feature module wires
              # its home-manager config for both accounts. Only the per-user home
              # and the sops identity differ here.
              home = {
                username = corpUser;
                homeDirectory = "/home/${corpUser}";
              };
              # accounts-daemon/AccountsService uses ~/.face for the greeter
              # avatar when no AccountsService icon is set.
              home.file.".face".source = "${mkAvatar "alexis-pigeon" "AP" palette.lavender}/avatar.png";
              stylix.targets = stylixTargets;
              # No software age key in this home: sec/sece use the YubiKey
              # identity shipped by modules.sops.interactiveYubikey.
              modules.sops = {
                ageKeyFile = "/home/${corpUser}/.config/sops/yubi-age-identity";
                useYubikey = false;
                interactiveYubikey = true;
                secretsFile = ../../secrets/corp.yaml;
              };
            };

            # Stylix targets for apps this host does not run (same list as the
            # workstation, plus the game/personal apps disabled above). Applied
            # to both accounts: a target left auto-enabled either fails
            # evaluation (wayprompt) or fights the repo's own theming (ghostty,
            # btop, starship, yazi, lazygit, bat).
            users.${localUser} = {
              home.file.".face".source = "${mkAvatar "alexis" "A" palette.mauve}/avatar.png";
              stylix.targets = stylixTargets;
              modules.sops = {
                # Boot decrypts corp.yaml with the persistent software key; the
                # YubiKey opens and edits secrets interactively (sec/sece/secx).
                ageKeyFile = "/home/${localUser}/.config/sops/age/keys.txt";
                useYubikey = false;
                interactiveYubikey = true;
                secretsFile = ../../secrets/corp.yaml;
              };
            };
          };
        }
      )
    ];
  };
}
