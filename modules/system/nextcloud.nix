{
  config,
  lib,
  ...
}:
let
  certFile = ../../config/ca/homelab-ca.pem;
  url = "https://nextcloud.alexyz.hl/remote.php/dav/files/alexyz";
  username = "alexyz";
  secretName = "NEXTCLOUD_PASSWORD";
  secretFile = ../../secrets/secrets.yaml;

  # Shared home-manager config for both NixOS hosts and standalone profiles.
  # `backend` is a constant picked at composition time (not a config option), so
  # no option read happens inside the config (which would recurse in home-manager).
  mkNextcloudHome =
    {
      config,
      lib,
      pkgs,
      mountPoint,
      backend,
      fstabMount,
    }:
    let
      secretPath = config.sops.secrets.${secretName}.path;
    in
    if backend == "rclone" then
      {
        home.packages = [ pkgs.rclone ];
        # Live in secrets.yaml (not env.yaml) so the password is never exported
        # into the shell environment.
        sops.secrets.${secretName} = {
          sopsFile = secretFile;
        };
        # Trust the homelab CA directly (rclone ignores the system store on macOS).
        programs.zsh.initContent = lib.mkOrder 950 ''
          ncm() {
            mkdir -p "${mountPoint}"
            rclone mount :webdav: "${mountPoint}" \
              --webdav-url "${url}" --webdav-vendor nextcloud --webdav-user "${username}" \
              --webdav-pass "$(rclone obscure "$(cat "${secretPath}")")" \
              --ca-cert "${certFile}" --vfs-cache-mode full &
          }
          ncu() {
            rclone umount "${mountPoint}"
          }
        '';
      }
    else
      let
        # With an fstab entry (NixOS) let mount(8) resolve device+options;
        # on standalone profiles call mount.davfs with the explicit URL.
        mountCmd = if fstabMount then "mount \"${mountPoint}\"" else "mount.davfs ${url} \"${mountPoint}\"";
      in
      {
        home.packages = [ pkgs.davfs2 ];
        sops.secrets.${secretName} = {
          sopsFile = secretFile;
        };
        # davfs2 verifies TLS against its own trust store: trust_ca_cert looks
        # the cert up in ~/.davfs2/certs (and /etc/davfs2/certs).
        home.file = {
          ".davfs2/certs/homelab-ca.pem".source = certFile;
          ".davfs2/davfs2.conf".text = "trust_ca_cert homelab-ca.pem\n";
        };
        programs.zsh.initContent = lib.mkOrder 950 ''
          ncm() {
            mkdir -p "$HOME/.davfs2" "${mountPoint}"
            chmod 700 "$HOME/.davfs2"
            printf '%s %s %s\n' "${url}" "${username}" "$(cat "${secretPath}")" > "$HOME/.davfs2/secrets"
            chmod 600 "$HOME/.davfs2/secrets"
            ${mountCmd}
          }
          ncu() {
            umount "${mountPoint}"
          }
        '';
      };
in
{
  flake.modules.nixos.nextcloud =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.nextcloud = {
        enable = lib.mkEnableOption "Nextcloud WebDAV mount (davfs2)";
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/nextcloud";
          description = "Mount point for the Nextcloud WebDAV share.";
        };
      };
      config = lib.mkIf config.modules.nextcloud.enable {
        environment.systemPackages = [ pkgs.davfs2 ];
        boot.kernelModules = [ "fuse" ];
        # mount.davfs (setuid) requires the davfs2 user and group to exist.
        users.groups.davfs2 = { };
        users.users.davfs2 = {
          group = "davfs2";
          isSystemUser = true;
        };
        # ... and the mounting user must be a member of the davfs2 group.
        users.users.${config.modules.users.userName}.extraGroups = [ "davfs2" ];
        # davfs2 performs the FUSE mount syscall itself (no fusermount), so
        # non-root `user` mounts need a setuid-root helper. It still reads the
        # calling user's ~/.davfs2/secrets via getuid().
        security.wrappers."mount.davfs" = {
          owner = "root";
          group = "root";
          setuid = true;
          source = "${pkgs.davfs2}/sbin/mount.davfs";
        };
        environment.etc."davfs2/certs/homelab-ca.pem".source = certFile;
        environment.etc."davfs2/davfs2.conf".text = "trust_ca_cert homelab-ca.pem\n";
        sops.secrets.${secretName} = {
          sopsFile = secretFile;
        };
        # noauto fstab mounts need an existing mount point owned by the user for
        # the `user` mount option to work — create it at boot.
        systemd.tmpfiles.rules = [
          "d ${config.modules.nextcloud.mountPoint} 0755 ${config.modules.users.userName} users -"
        ];
        fileSystems."${config.modules.nextcloud.mountPoint}" = {
          device = url;
          fsType = "davfs";
          options = [
            "rw"
            "user"
            "noauto"
          ];
        };
        home-manager.users.${config.modules.users.userName} =
          let
            mountPoint = config.modules.nextcloud.mountPoint;
          in
          {
            config,
            lib,
            pkgs,
            ...
          }:
          mkNextcloudHome {
            inherit
              config
              lib
              pkgs
              mountPoint
              ;
            backend = "davfs";
            fstabMount = true;
          };
      };
    };

  flake.modules.homeManager.nextcloud =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.nextcloud = {
        enable = lib.mkEnableOption "Nextcloud WebDAV mount (davfs2)";
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "$HOME/nextcloud";
          description = "Mount point for the Nextcloud WebDAV share.";
        };
      };
      config = lib.mkIf config.modules.nextcloud.enable (mkNextcloudHome {
        inherit config lib pkgs;
        mountPoint = config.modules.nextcloud.mountPoint;
        backend = "davfs";
        fstabMount = false;
      });
    };

  # macOS: davfs2 is Linux-only (FUSE), so mount via rclone + macFUSE instead.
  flake.modules.homeManager.nextcloudRclone =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.nextcloudRclone = {
        enable = lib.mkEnableOption "Nextcloud WebDAV mount (rclone)";
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "$HOME/nextcloud";
          description = "Mount point for the Nextcloud WebDAV share.";
        };
      };
      config = lib.mkIf config.modules.nextcloudRclone.enable (mkNextcloudHome {
        inherit config lib pkgs;
        mountPoint = config.modules.nextcloudRclone.mountPoint;
        backend = "rclone";
        fstabMount = false;
      });
    };
}
