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
          description = ''
            System files linked into persistence. The SSH host keys are added
            automatically (see the sshd hostKeys list), so never persist
            /etc/ssh as a directory: the empty persistent copy hides the
            generated sshd_config and sshd then fails to start.
          '';
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

        warnings = lib.optional (lib.elem "/etc/ssh" config.modules.impermanence.directories) ''
          modules.impermanence.directories contains "/etc/ssh". Bind-mounting the
          directory hides the generated sshd_config and host keys on a fresh
          install (sshd then fails to start). Persist the ssh_host_* files
          instead, which the default `files` list already does.
        '';

        environment.persistence.${config.modules.impermanence.persistPath} = {
          hideMounts = true;
          # "/etc/ssh" is dropped even if a host still lists it: see the warning.
          directories = builtins.filter (d: d != "/etc/ssh") config.modules.impermanence.directories;
          # Persist every host key sshd is configured to use, whatever key types
          # the current openssh default generates (rsa, ed25519,
          # mldsa44_ed25519), plus the machine id.
          files =
            config.modules.impermanence.files
            ++ lib.optionals (config.services ? openssh) (
              lib.concatMap (key: [
                key.path
                "${key.path}.pub"
              ]) config.services.openssh.hostKeys
            );
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
