_:
let
  corpSecrets = ../../secrets/corp.yaml;
in
{
  nixconf.modules.nixos.corpNas =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.modules.corpNas;
      shareList = lib.attrValues cfg.shares;
      secretNames = lib.unique (
        lib.concatMap (share: [
          share.usernameSecret
          share.passwordSecret
        ]) shareList
      );
      mountOptions = name: _share: [
        "credentials=${config.sops.templates."${name}.cred".path}"
        "uid=${toString cfg.uid}"
        "gid=${toString cfg.gid}"
        "iocharset=utf8"
        "nofail"
        "_netdev"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "x-systemd.mount-timeout=15"
        "x-systemd.device-timeout=15"
      ];
    in
    {
      options.modules.corpNas = {
        enable = lib.mkEnableOption "nas1 (Q:) SMB shares mounted over cifs";

        uid = lib.mkOption {
          type = lib.types.int;
          default = 1000;
          description = "Local owner of the files on every share.";
        };

        gid = lib.mkOption {
          type = lib.types.int;
          default = 100;
          description = "Local group of the files on every share.";
        };

        shares = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                source = lib.mkOption {
                  type = lib.types.str;
                  description = "UNC path of the share.";
                };
                mountPoint = lib.mkOption {
                  type = lib.types.str;
                  description = "Where the share is mounted.";
                };
                usernameSecret = lib.mkOption {
                  type = lib.types.str;
                  default = "corp/nas_username";
                  description = "sops key holding the SMB user for this share.";
                };
                passwordSecret = lib.mkOption {
                  type = lib.types.str;
                  default = "corp/nas_password";
                  description = "sops key holding the SMB password for this share.";
                };
              };
            }
          );
          default = {
            public = {
              source = "//10.113.8.28/Public";
              mountPoint = "/mnt/qraid";
            };
          };
          description = ''
            Shares to automount. Defaults to the Public/Q: volume from the
            enrollment guide; hosts add entries with their own credentials when
            a share needs the user's AD account instead of the shared service
            account.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets = lib.genAttrs secretNames (_: {
          sopsFile = corpSecrets;
        });

        sops.templates = lib.mapAttrs' (
          name: share:
          lib.nameValuePair "${name}.cred" {
            mode = "0400";
            content = ''
              username=${config.sops.placeholder.${share.usernameSecret}}
              password=${config.sops.placeholder.${share.passwordSecret}}
            '';
          }
        ) cfg.shares;

        boot.supportedFilesystems = [ "cifs" ];

        # security.lockKernelModules sets kernel.modules_disabled=1 after boot,
        # so anything SMB3 needs must be preloaded: cifs negotiates AEAD for
        # signing/encryption and mount.cifs fails with "smb3_crypto_aead_allocate:
        # Failed alloc encrypt aead" (ENOENT) when ccm(aes) is absent.
        boot.kernelModules = [
          "cifs"
          "ccm"
          "gcm"
        ];

        # automount + nofail: a missing/unreachable share must never block boot.
        fileSystems = lib.mapAttrs' (
          name: share:
          lib.nameValuePair share.mountPoint {
            device = share.source;
            fsType = "cifs";
            options = mountOptions name share;
          }
        ) cfg.shares;

        systemd.tmpfiles.rules = map (share: "d ${share.mountPoint} 0755 root root -") shareList;
      };
    };
}
