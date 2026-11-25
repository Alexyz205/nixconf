_: {
  nixconf.modules.nixos.nas =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.nas;
      resticDirs = map (repo: "/srv/restic/${repo}") cfg.resticRepos;
    in
    {
      options.modules.nas = {
        enable = lib.mkEnableOption "backup NAS (ZFS pool, NFSv4, SFTP/restic, snapshots, UPS)";

        poolName = lib.mkOption {
          type = lib.types.str;
          default = "tank";
          description = "ZFS pool that holds the backup datasets.";
        };

        nfsClients = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "192.168.1.0/24" ];
          description = "Clients allowed to mount the Longhorn backup export.";
        };

        resticRepos = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "workstation"
            "headless-worker"
          ];
          description = "Subdirectories under /srv/restic, one per restic client.";
        };

        resticAuthorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys allowed to use the SFTP-only 'backup' user.";
        };

        lanCidr = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.0/24";
          description = "LAN allowed to scrape node_exporter.";
        };

        exportNodeMetrics = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Expose node_exporter on 9100 to the LAN.";
        };

        ups = {
          enable = lib.mkEnableOption "NUT UPS monitoring and clean shutdown";
          name = lib.mkOption {
            type = lib.types.str;
            default = "ups";
          };
          driver = lib.mkOption {
            type = lib.types.str;
            default = "usbhid-ups";
          };
          port = lib.mkOption {
            type = lib.types.str;
            default = "auto";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # Required even with ZFS-native mountpoints (no fileSystems entries):
        # makes boot.zfs.enabled true, pulls in the kernel module and the
        # zfs-import/zfs-mount units.
        boot.supportedFilesystems = [ "zfs" ];
        boot.zfs.extraPools = [ cfg.poolName ];
        # 16GB total: cap ARC at 8GiB and leave the rest for NFS/SFTP/restic.
        boot.extraModprobeConfig = "options zfs zfs_arc_max=8589934592";

        # Use ZFS-native mountpoints instead of fstab mount units: with
        # mountpoint=legacy, systemd's `zfs mount` path fails ("cannot be
        # mounted using zfs mount"). zfs-mount.service handles these.
        systemd.services.zfs-data-mountpoints = {
          description = "Set ZFS mountpoints for NAS datasets";
          after = [ "zfs-import-${cfg.poolName}.service" ];
          requires = [ "zfs-import-${cfg.poolName}.service" ];
          before = [ "zfs-mount.service" ];
          wantedBy = [ "zfs-mount.service" ];
          serviceConfig.Type = "oneshot";
          script = ''
            ${config.boot.zfs.package}/bin/zfs set mountpoint=/srv/nfs/longhorn ${cfg.poolName}/longhorn || true
            ${config.boot.zfs.package}/bin/zfs set mountpoint=/srv/restic ${cfg.poolName}/restic || true
            ${config.boot.zfs.package}/bin/zfs set mountpoint=/srv/backup ${cfg.poolName}/backup || true
          '';
        };

        services.zfs = {
          autoSnapshot = {
            enable = true;
            flags = "-k -p --utc";
            frequent = 0;
            hourly = 24;
            daily = 7;
            weekly = 4;
            monthly = 6;
          };
          autoScrub = {
            enable = true;
            interval = "monthly";
            pools = [ cfg.poolName ];
          };
          # The data vdev is HDD; TRIM is for SSDs.
          trim.enable = false;
        };

        services.nfs.server = {
          enable = true;
          createMountPoints = true;
          exports = {
            "/srv/nfs/longhorn" = lib.genAttrs cfg.nfsClients (_: [
              "rw"
              "sync"
              "no_subtree_check"
              "no_root_squash"
            ]);
          };
        };
        systemd.services.nfs-server = {
          after = [ "zfs-mount.service" ];
          wants = [ "zfs-mount.service" ];
        };
        systemd.services.nfs-mountd = {
          after = [ "zfs-mount.service" ];
          wants = [ "zfs-mount.service" ];
        };

        services.openssh.extraConfig = ''
          Match User backup
            ForceCommand internal-sftp
            AllowTcpForwarding no
            X11Forwarding no
            PermitTTY no
        '';

        users.groups.backup = { };
        users.users.backup = {
          isNormalUser = true;
          group = "backup";
          home = "/srv/restic";
          createHome = false;
          shell = pkgs.bash;
          openssh.authorizedKeys.keys = cfg.resticAuthorizedKeys;
        };

        systemd.services.restic-repo-dirs = {
          description = "Create restic repository directories";
          after = [ "zfs-mount.service" ];
          requires = [ "zfs-mount.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            ${pkgs.coreutils}/bin/install -d -m 0700 -o backup -g backup ${lib.escapeShellArgs resticDirs}
          '';
        };

        # extraInputRules is implemented by the nftables backend only; with the
        # default iptables firewall the option is accepted and silently
        # discarded, which leaves node_exporter unreachable despite the rule
        # below. Enabling nftables is the supported backend switch (setting
        # networking.firewall.backend alone trips the extraCommands assert).
        networking.nftables.enable = lib.mkIf cfg.exportNodeMetrics true;

        networking.firewall = {
          allowedTCPPorts = [ 2049 ];
          allowedUDPPorts = [ 2049 ];
          extraInputRules = lib.optionalString cfg.exportNodeMetrics ''
            ip saddr ${cfg.lanCidr} tcp dport 9100 accept
          '';
        };

        # Local-only NUT password; generated at boot, never in the Nix store.
        systemd.services.nut-password = lib.mkIf cfg.ups.enable {
          description = "Generate the local NUT upsmon password";
          before = [
            "upsd.service"
            "upsmon.service"
          ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.coreutils}/bin/install -d -m 0755 /etc/nut
            if [ ! -s /etc/nut/upsmon.pass ]; then
              ${pkgs.openssl}/bin/openssl rand -hex 16 > /etc/nut/upsmon.pass
            fi
            ${pkgs.coreutils}/bin/chmod 0600 /etc/nut/upsmon.pass
          '';
        };

        power.ups = lib.mkIf cfg.ups.enable {
          enable = true;
          mode = "standalone";
          ups.${cfg.ups.name} = {
            driver = cfg.ups.driver;
            port = cfg.ups.port;
            description = "NAS UPS";
          };
          users.upsmon = {
            passwordFile = "/etc/nut/upsmon.pass";
            upsmon = "primary";
          };
          upsmon = {
            enable = true;
            monitor.${cfg.ups.name} = {
              system = cfg.ups.name;
              powerValue = 1;
              user = "upsmon";
              passwordFile = "/etc/nut/upsmon.pass";
              type = "primary";
            };
          };
        };

        system.activationScripts.zfsAutoSnapshot = {
          deps = [ "specialfs" ];
          text = ''
            for ds in ${
              lib.escapeShellArgs (
                map (d: "${cfg.poolName}/${d}") [
                  "longhorn"
                  "restic"
                  "backup"
                ]
              )
            }; do
              ${config.boot.zfs.package}/bin/zfs set com.sun:auto-snapshot=true "$ds" 2>/dev/null || true
            done
          '';
        };

        # Weekly local replication to a USB pool named "offsite". The timer is a
        # no-op when the disk is not connected.
        systemd.services.zfs-offsite = {
          description = "Replicate the backup pool to the offsite USB disk";
          after = [ "zfs-mount.service" ];
          path = [
            pkgs.zfs
            pkgs.sanoid
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
          script = ''
            if ! zpool list offsite >/dev/null 2>&1; then
              echo "offsite pool not present; skipping"
              exit 0
            fi
            exec syncoid --recursive --no-privilege-elevation --no-sync-snap \
              ${cfg.poolName} offsite/${cfg.poolName}
          '';
        };

        systemd.timers.zfs-offsite = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
          };
        };

        environment.systemPackages = [
          pkgs.sanoid
          pkgs.smartmontools
        ];
      };
    };
}
