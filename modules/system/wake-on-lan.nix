_: {
  nixconf.modules.nixos.wakeOnLan =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.wakeOnLan;
      wolScript = ''
        if [ ${toString (builtins.length cfg.interfaces)} -eq 0 ]; then
          set -- /sys/class/net/en*
        else
          set -- ${lib.escapeShellArgs cfg.interfaces}
        fi
        for path in "$@"; do
          [ -e "$path" ] || continue
          name=''${path##*/}
          ${pkgs.ethtool}/bin/ethtool -s "$name" wol g || true
        done
      '';
    in
    {
      options.modules.wakeOnLan = {
        enable = lib.mkEnableOption "Wake-on-LAN magic packets on wired NICs";
        interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Wired interfaces to enable (for example enp4s0). Empty means every
            interface whose kernel name starts with en.
          '';
        };
        sleepState = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "s2idle"
              "shallow"
              "deep"
            ]
          );
          default = null;
          description = ''
            Kernel suspend state to select with mem_sleep_default. Set "deep"
            for S3, where NIC wake-on-LAN is reliable; leave null to keep the
            firmware/kernel default (often s2idle).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelParams = lib.optional (cfg.sleepState != null) "mem_sleep_default=${cfg.sleepState}";

        # networkd applies WakeOnLan at link setup; NetworkManager hosts get
        # the runtime ethtool call below. Both are idempotent.
        networking.interfaces = lib.genAttrs cfg.interfaces (_: {
          wakeOnLan.enable = true;
        });

        systemd.services.wake-on-lan = {
          description = "Enable Wake-on-LAN magic packet reception";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = wolScript;
        };

        # NetworkManager may reset the NIC when the link goes down; reapply
        # right before every suspend so WoL still works from S3.
        systemd.services.wake-on-lan-before-sleep = {
          description = "Re-enable Wake-on-LAN before sleep";
          before = [ "sleep.target" ];
          wantedBy = [ "sleep.target" ];
          serviceConfig = {
            Type = "oneshot";
          };
          script = wolScript;
        };

        environment.systemPackages = [ pkgs.ethtool ];
      };
    };
}
