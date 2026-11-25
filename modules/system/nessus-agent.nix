_:
let
  corpSecrets = ../../secrets/corp.yaml;
in
{
  nixconf.modules.nixos.nessusAgent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.nessusAgent;
      stateDir = "/var/lib/nessus_agent";
      home = "/opt/nessus_agent";
      agentDeb = pkgs.fetchurl {
        url = "https://packages.gametools.dev/artifactory/dxz-assets/security/nessus_agent/NessusAgent-10.1.0-ubuntu1110_amd64.deb";
        hash = "sha256-i4sFOI8aS3EFWifALHuCc9X1UuUNgfscUqiKjUtVHM0=";
      };
      agent = pkgs.stdenvNoCC.mkDerivation {
        pname = "nessus-agent";
        version = "10.1.0";
        src = agentDeb;

        nativeBuildInputs = with pkgs; [
          dpkg
          autoPatchelfHook
          patchelf
          zlib
        ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];

        unpackPhase = ''
          runHook preUnpack
          dpkg-deb -x "$src" .
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -r opt "$out/opt"
          runHook postInstall
        '';

        # The agent ships self-contained helpers; only the entry points link
        # against the system loader.
        dontAutoPatchelf = true;
        preFixup = ''
          addAutoPatchelfSearchPath "$out/opt/nessus_agent/lib/nessus"
          autoPatchelf "$out/opt/nessus_agent/sbin" "$out/opt/nessus_agent/bin"
        '';
      };
      cli = "${home}/sbin/nessuscli";
    in
    {
      options.modules.nessusAgent = {
        enable = lib.mkEnableOption "Tenable Nessus Agent (corporate vulnerability scanner)";

        groups = lib.mkOption {
          type = lib.types.str;
          default = "RNS";
          description = "Agent group on the Tenable manager.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "enterprise.alcatraz.dev";
          description = "Nessus manager host.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 8834;
          description = "Nessus manager port.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets."corp/nessus_key" = {
          sopsFile = corpSecrets;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        environment.systemPackages = [ agent ];

        # The agent hardcodes /opt/nessus_agent for its prefix and writes its
        # plugin set, logs and state there. /opt is on the ephemeral root, so the
        # real state lives on the persistent volume and is bind-mounted in.
        systemd.tmpfiles.rules = [ "d ${stateDir} 0700 root root -" ];
        systemd.mounts = [
          {
            what = stateDir;
            where = home;
            type = "none";
            options = "bind";
            unitConfig = {
              DefaultDependencies = "no";
              Conflicts = "umount.target";
              Before = "umount.target";
            };
          }
        ];

        systemd.services.nessus-agent-init = {
          description = "Seed the Nessus Agent prefix from the package";
          wantedBy = [ "nessusagent.service" ];
          before = [ "nessusagent.service" ];
          requires = [ "opt-nessus_agent.mount" ];
          after = [ "opt-nessus_agent.mount" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu
            if [ -z "$(ls -A ${stateDir})" ]; then
              cp -a ${agent}/opt/nessus_agent/. ${stateDir}/
              chown -R root:root ${stateDir}
              ${cli} install ${stateDir}/var/nessus/plugins-core.tar.gz >/dev/null
            fi
          '';
        };

        systemd.services.nessusagent = {
          description = "The Nessus Client Agent";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
            "nessus-agent-init.service"
          ];
          requires = [
            "opt-nessus_agent.mount"
            "nessus-agent-init.service"
          ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "simple";
            PIDFile = "${stateDir}/var/nessus/nessus-service.pid";
            Environment = "NESSUS_TZ_DIR=${pkgs.tzdata}/share/zoneinfo";
            ExecStart = "${home}/sbin/nessus-service -q";
            ExecReload = "${pkgs.procps}/bin/pkill nessusd";
            Restart = "on-abort";
            RestartSec = 10;
          };
        };

        # Linking is a one-time enrollment; guard it with a stamp file so a
        # reboot never re-registers the agent under a new name.
        systemd.services.nessus-agent-link = {
          description = "Link Nessus Agent to the corporate manager";
          wantedBy = [ "multi-user.target" ];
          after = [ "nessusagent.service" ];
          requires = [ "nessusagent.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu
            stamp=${stateDir}/.linked
            if [ -e "$stamp" ]; then
              exit 0
            fi
            ${cli} agent link \
              --key="$(cat ${config.sops.secrets."corp/nessus_key".path})" \
              --groups=${lib.escapeShellArg cfg.groups} \
              --host=${lib.escapeShellArg cfg.host} \
              --port=${toString cfg.port}
            touch "$stamp"
          '';
        };
      };
    };
}
