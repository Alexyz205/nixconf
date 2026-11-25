_: {
  nixconf.modules.nixos.backup =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.backup = {
        enable = lib.mkEnableOption "restic backups";
        repository = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "sftp:backup-nas:/srv/restic/headless-worker";
          description = ''
            Restic repository URL. Required when enable is true; the module does
            not guess a destination.
          '';
        };
        passwordFile = lib.mkOption {
          type = lib.types.str;
          default = "/run/secrets/RESTIC_PASSWORD";
          description = ''
            File containing the restic repository password. Add
            `sops.secrets.RESTIC_PASSWORD = { };` to the host (see
            docs/backup.md) so sops-nix materialises it at this path.
          '';
        };
        sshHost = lib.mkOption {
          type = lib.types.str;
          default = "backup-nas";
          description = "SSH Host alias used for sftp: repositories.";
        };
        sshHostName = lib.mkOption {
          type = lib.types.str;
          default = "nas.alexyz.org";
          description = ''
            Address behind the SSH Host alias. The PiHole record is the source
            of truth; set it to an IP only if this host must back up while
            cluster DNS is unavailable.
          '';
        };
        sshKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "/run/secrets/RESTIC_SSH_KEY";
          description = "Private key used for sftp: repositories (root-owned, 0400).";
        };
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/etc"
            "/home"
            "/var/lib"
          ];
          description = "Paths included in the snapshot.";
        };
        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/var/lib/systemd/coredump"
            "/var/crash"
            "core.*"
            "*.core"
            "/home/*/Games"
            "/home/*/.local/share/Steam"
            "/home/*/.steam"
            "/home/*/.local/share/PrismLauncher"
            "**/steamapps"
            "/home/*/.local/share/containers"
            "/home/*/.cache"
            "/root/.cache"
            "/var/lib/containers"
            "/var/lib/docker"
            "/var/lib/libvirt"
            "/var/lib/machines"
            "/var/lib/lxd"
          ];
          description = ''
            Restic exclude patterns. Core dumps are never useful in a backup.
            Game libraries (Steam, PrismLauncher) are re-downloadable and can be
            hundreds of GiB; keep them out of the snapshot. Container storage
            (podman/docker) and VM disk images are live and mutate while being
            read, which makes restic abort on hash mismatches; back those up
            with native dumps/snapshots instead.
          '';
        };
        timer = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar expression for the backup timer.";
        };
        keep = lib.mkOption {
          type = lib.types.attrsOf lib.types.int;
          default = {
            daily = 7;
            weekly = 4;
            monthly = 6;
          };
          description = "Retention policy passed to `restic forget --prune`.";
        };
      };

      config = lib.mkIf config.modules.backup.enable {
        assertions = [
          {
            assertion = config.modules.backup.repository != "";
            message = "modules.backup.enable requires modules.backup.repository to be set (see docs/backup.md).";
          }
        ];

        # `restic-nas snapshots`, `restic-nas ls latest`, ... with the
        # repository and password file already set. sudo is required because
        # the sops password/key are root-only.
        environment.systemPackages = [
          (pkgs.writeShellScriptBin "restic-nas" ''
            exec sudo ${pkgs.restic}/bin/restic \
              -r ${config.modules.backup.repository} \
              --password-file ${config.modules.backup.passwordFile} \
              "$@"
          '')
        ];
        environment.shellAliases.rs = "restic-nas";
        # Home-manager's zsh does not source /etc/zshrc, so define the alias
        # in the user's shell config as well.
        home-manager.sharedModules = [
          {
            programs.zsh.shellAliases.rs = "restic-nas";
          }
        ];

        programs.ssh.extraConfig = lib.mkIf (lib.hasPrefix "sftp:" config.modules.backup.repository) ''
          Host ${config.modules.backup.sshHost}
            HostName ${config.modules.backup.sshHostName}
            User backup
            IdentityFile ${config.modules.backup.sshKeyFile}
            IdentitiesOnly yes
            StrictHostKeyChecking accept-new
        '';

        services.restic.backups.daily = {
          inherit (config.modules.backup)
            repository
            passwordFile
            paths
            exclude
            ;
          initialize = true;
          pruneOpts = lib.mapAttrsToList (
            unit: count: "--keep-${unit} ${toString count}"
          ) config.modules.backup.keep;
          timerConfig = {
            OnCalendar = config.modules.backup.timer;
            Persistent = true;
          };
        };
      };
    };
}
