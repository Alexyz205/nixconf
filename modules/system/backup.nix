_: {
  nixconf.modules.nixos.backup =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.backup = {
        enable = lib.mkEnableOption "restic backups";
        repository = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "sftp:backup@nas:/srv/restic/headless-worker";
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
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/etc"
            "/home"
            "/var/lib"
          ];
          description = "Paths included in the snapshot.";
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

        services.restic.backups.daily = {
          inherit (config.modules.backup) repository passwordFile paths;
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
