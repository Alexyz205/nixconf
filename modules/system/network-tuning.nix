_: {
  flake.modules.nixos.networkTuning =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options.modules.networkTuning = {
        enable = lib.mkEnableOption "TCP/network performance tuning (BBR + fq + buffers)";
        interface = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "enp4s0";
          description = ''
            Physical interface whose Energy Efficient Ethernet (EEE) feature
            should be disabled. Set this on Intel I225/I226 (igc) NICs, where
            EEE causes 2.5GbE link flapping. Leave null to skip.
          '';
        };
      };

      config = lib.mkIf config.modules.networkTuning.enable {
        # BBR ships as a module; load it explicitly so the sysctl below can
        # select it even with security.lockKernelModules blocking later
        # on-demand module loading.
        boot.kernelModules = [ "tcp_bbr" ];

        boot.kernel.sysctl = {
          # BBR + fair-queue pacing: faster ramp-up and higher throughput on
          # high-bandwidth/high-latency links than the default CUBIC.
          "net.core.default_qdisc" = "fq";
          "net.ipv4.tcp_congestion_control" = "bbr";

          # Socket buffers sized for multi-gigabit links (kernel default max
          # is often only ~4MB).
          "net.core.rmem_max" = 16777216;
          "net.core.wmem_max" = 16777216;
          "net.ipv4.tcp_rmem" = "4096 87380 16777216";
          "net.ipv4.tcp_wmem" = "4096 65536 16777216";

          # Deeper per-CPU RX queue so 2.5G bursts are not dropped.
          "net.core.netdev_max_backlog" = 5000;
        };

        # Disable EEE through ethtool rather than systemd's
        # [EnergyEfficientEthernet] link section: networkd's ioctl cannot carry
        # EEE link modes beyond bit 32, so it is a silent no-op on 2500baseT.
        # ethtool uses netlink and works.
        systemd.services.disable-eee = lib.mkIf (config.modules.networkTuning.interface != null) {
          description = "Disable Energy Efficient Ethernet (EEE) on ${config.modules.networkTuning.interface}";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-pre.target" ];
          after = [ "network-pre.target" ];
          before = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.ethtool}/bin/ethtool --set-eee ${config.modules.networkTuning.interface} eee off";
          };
        };
      };
    };
}
