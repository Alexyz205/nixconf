{
  inputs,
  ...
}:
let
  impermanenceCfg =
    {
      config,
      lib,
      ...
    }:
    {
      # Provides environment.persistence.* (and home.persistence on the HM side).
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      options.modules.impermanence = {
        enable = lib.mkEnableOption "impermanence (ephemeral root, /persistent state)";

        tmpfsRoot = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Mount / as tmpfs. /home, /nix and /persistent stay on btrfs.
            Set false if the host rotates the btrfs /root subvolume instead.
          '';
        };

        persistPath = lib.mkOption {
          type = lib.types.str;
          default = "/persistent";
          description = "Mount point of the volume that survives reboots.";
        };

        directories = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
          default = [
            "/var/log"
            "/var/lib/nixos"
            "/var/lib/systemd/coredump"
          ];
          description = "System directories bind-mounted into persistence.";
        };

        files = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
          default = [ "/etc/machine-id" ];
          description = "System files linked into persistence.";
        };

        userDirectories = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
          default = [
            ".ssh"
            {
              directory = ".gnupg";
              mode = "0700";
            }
            {
              directory = ".local/share/keyrings";
              mode = "0700";
            }
            ".local/share/direnv"
          ];
          description = "User (home) directories to persist.";
        };

        userFiles = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
          default = [ ];
          description = "User (home) files to persist.";
        };
      };

      # Opt-in only: enabling this wires environment.persistence, but the root
      # itself must be made ephemeral by the host's filesystem config (tmpfs
      # root or a rotated btrfs subvolume) plus a persistent volume. See
      # docs/impermanence.md before enabling.
      config = lib.mkIf config.modules.impermanence.enable {
        # tmpfs root: only writes to / consume RAM; /home, /nix and
        # /persistent are separate btrfs mounts and survive reboots.
        fileSystems."/" = lib.mkIf config.modules.impermanence.tmpfsRoot (
          lib.mkForce {
            fsType = "tmpfs";
            device = "none";
            neededForBoot = true;
            options = [
              "size=50%"
              "mode=0755"
            ];
          }
        );
        fileSystems."/nix".neededForBoot = lib.mkIf config.modules.impermanence.tmpfsRoot (
          lib.mkDefault true
        );
        fileSystems."/home".neededForBoot = lib.mkIf config.modules.impermanence.tmpfsRoot (
          lib.mkDefault true
        );
        fileSystems."/persistent".neededForBoot = lib.mkIf config.modules.impermanence.tmpfsRoot (
          lib.mkDefault true
        );

        environment.persistence.${config.modules.impermanence.persistPath} = {
          hideMounts = true;
          directories = config.modules.impermanence.directories;
          files = config.modules.impermanence.files;
          users.${config.modules.users.userName} = {
            directories = config.modules.impermanence.userDirectories;
            files = config.modules.impermanence.userFiles;
          };
        };
      };
    };
in
{
  flake-file.inputs.impermanence = {
    url = "github:nix-community/impermanence";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };

  nixconf.modules.nixos.impermanence = impermanenceCfg;
}
