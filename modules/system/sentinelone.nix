{
  inputs,
  ...
}:
let
  corpSecrets = ../../secrets/corp.yaml;
in
{
  flake-file.inputs.sentinelone = {
    url = "github:devusb/sentinelone-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixconf.modules.nixos.sentinelone =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.sentinelone;
      # Debian package from the Take-Two enrollment bundle. It is proprietary, so
      # it is never vendored in this repo; the hash pins the exact build the
      # mirror serves. Bump URL + hash together if the console pushes a new one.
      agentDeb = pkgs.fetchurl {
        url = "https://packages.gametools.dev/artifactory/dxz-assets/security/sentinel_one/SentinelAgent_linux_v21_10_3_3.deb";
        hash = "sha256-BT1MWAyGXWxLcuRFjRL1IyQYrGoHb3OAXpzm8IYAtGE=";
      };
      agent = pkgs.stdenvNoCC.mkDerivation {
        pname = "sentinelone";
        version = "21.10.3.3";
        src = agentDeb;

        nativeBuildInputs = with pkgs; [
          dpkg
          autoPatchelfHook
          patchelf
          zlib
          elfutils
        ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];

        unpackPhase = ''
          runHook preUnpack
          dpkg-deb -x "$src" .
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/opt"
          cp -r opt/* "$out/opt"
          # The devusb module bind-mounts bin/ebpfs/ranger; 21.x has no ranger.
          mkdir -p "$out/opt/sentinelone/ranger"
          runHook postInstall
        '';

        dontAutoPatchelf = true;
        dontPatchELF = true;

        preFixup = ''
          patchelf --replace-needed libelf.so.0 libelf.so "$out/opt/sentinelone/lib/libbpf.so"
        '';

        # sentinelctl is left unpatched: the upstream module runs it through an
        # FHS bwrap wrapper. Everything else (the agent included) must get the
        # Nix loader or systemd fails it with status 127.
        postFixup = ''
          addAutoPatchelfSearchPath "$out/opt/sentinelone/lib"
          autoPatchelf $(find "$out/opt/sentinelone" -type f ! -path "$out/opt/sentinelone/bin/sentinelctl")
        '';
      };
    in
    {
      imports = [ inputs.sentinelone.nixosModules.sentinelone ];

      options.modules.sentinelone = {
        enable = lib.mkEnableOption "SentinelOne security agent (corporate EDR)";

        customerId = lib.mkOption {
          type = lib.types.str;
          default = "alexis.pigeon@take2games.com-RNSW-APIGEON1";
          description = "Identifier the console shows for this host.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets."corp/sentinelone_site_key" = {
          sopsFile = corpSecrets;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        services.sentinelone = {
          enable = true;
          package = agent;
          inherit (cfg) customerId;
          sentinelOneManagementTokenPath = config.sops.secrets."corp/sentinelone_site_key".path;
          dataDir = "/var/lib/sentinelone";
        };

        # 21.10 daemonizes (the vendor unit is Type=forking with a PID file);
        # the upstream module starts it as Type=exec, so systemd sees the
        # parent exit and tears the service down right after startup.
        systemd.services.sentinelone.serviceConfig = {
          Type = lib.mkForce "forking";
          PIDFile = lib.mkForce "/var/lib/sentinelone/configuration/agent.pid";
          KillMode = lib.mkForce "process";
          ExecStartPre = lib.mkForce "${pkgs.coreutils}/bin/rm -f /var/lib/sentinelone/configuration/agent.pid";
        };

        # The agent loads eBPF programs (and, depending on the detection mode,
        # kernel modules) at runtime, which modules_disabled=1 would block.
        security.lockKernelModules = lib.mkForce false;
      };
    };
}
