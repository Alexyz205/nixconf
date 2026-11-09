_: {
  nixconf.modules.nixos.monitoring =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.monitoring = {
        enable = lib.mkEnableOption "node exporter, SMART monitoring and btrfs scrub";
        expose = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Bind node_exporter to all interfaces and open TCP 9100 to a Prometheus scraper.";
        };
        btrfsMounts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/"
            "/home"
            "/nix"
          ];
          description = "btrfs mountpoints scrubbed weekly.";
        };
      };

      config = lib.mkIf config.modules.monitoring.enable {
        services.prometheus.exporters.node = {
          enable = true;
          port = 9100;
          listenAddress = if config.modules.monitoring.expose then "0.0.0.0" else "127.0.0.1";
          enabledCollectors = [
            "systemd"
            "processes"
            "tcpstat"
            "conntrack"
            "diskstats"
            "filesystem"
            "hwmon"
            "rapl"
          ];
        };
        networking.firewall.allowedTCPPorts = lib.mkIf config.modules.monitoring.expose [ 9100 ];

        services.smartd.enable = true;

        services.btrfs.autoScrub = {
          enable = true;
          interval = "weekly";
          fileSystems = config.modules.monitoring.btrfsMounts;
        };

        # Bound the journal so a chatty server cannot fill the root volume.
        services.journald.settings.Journal = {
          SystemMaxUse = "1G";
          MaxRetentionSec = "1month";
        };
      };
    };
}
