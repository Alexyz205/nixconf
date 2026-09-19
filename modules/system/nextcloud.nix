{
  config,
  lib,
  ...
}:
let
  url = "https://dev-nextcloud.alexyz.org/remote.php/dav/files/alexyz";
  username = "alexyz";
  secretName = "NEXTCLOUD_PASSWORD";
  secretFile = ../../secrets/secrets.yaml;

  # Options shared by the NixOS side (system mount) and both home-manager
  # backends (user mount). The mount point default differs per context.
  mkOptions = mountPointDefault: {
    enable = lib.mkEnableOption "Nextcloud WebDAV mount";
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = mountPointDefault;
      description = "Mount point for the Nextcloud WebDAV share.";
    };
  };

  # Shared home-manager config for all backends. `backend` is a constant picked
  # at composition time (not a config option), so no option read happens inside
  # the config (which would recurse in home-manager).
  #   - rclone : macOS (davfs2 is Linux-only), user mount via macFUSE.
  #   - systemd: NixOS, the mount is owned by a systemd .mount unit; ncm/ncu
  #     start/stop the unit. The fstab `user` option grants the user a
  #     passwordless start/stop, and credentials are provisioned system-wide
  #     (/etc/davfs2/secrets) by the NixOS side.
  #   - davfs  : standalone Linux profiles, setuid user mount reading
  #     ~/.davfs2/secrets.
  mkNextcloudHome =
    {
      config,
      lib,
      pkgs,
      mountPoint,
      backend,
    }:
    if backend == "rclone" then
      let
        secretPath = config.sops.secrets.${secretName}.path;
      in
      {
        home.packages = [ pkgs.rclone ];
        # Live in secrets.yaml (not env.yaml) so the password is never exported
        # into the shell environment.
        sops.secrets.${secretName} = {
          sopsFile = secretFile;
        };
        programs.zsh.initContent = lib.mkOrder 950 ''
          ncm() {
            mkdir -p "${mountPoint}"
            rclone mount :webdav: "${mountPoint}" \
              --webdav-url "${url}" --webdav-vendor nextcloud --webdav-user "${username}" \
              --webdav-pass "$(rclone obscure "$(cat "${secretPath}")")" \
              --vfs-cache-mode full &
          }
          ncu() {
            rclone umount "${mountPoint}"
          }
        '';
      }
    else if backend == "systemd" then
      let
        # systemd-escape of the mount point: /mnt/nextcloud -> mnt-nextcloud.mount
        mountUnit = "${builtins.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" mountPoint)}.mount";
      in
      {
        programs.zsh.initContent = lib.mkOrder 950 ''
          ncm() {
            systemctl start ${mountUnit}
          }
          ncu() {
            systemctl stop ${mountUnit}
          }
        '';
      }
    else
      let
        # Standalone: call the distro's setuid mount.davfs with the explicit URL.
        secretPath = config.sops.secrets.${secretName}.path;
      in
      {
        home.packages = [ pkgs.davfs2 ];
        sops.secrets.${secretName} = {
          sopsFile = secretFile;
        };
        programs.zsh.initContent = lib.mkOrder 950 ''
          ncm() {
            mkdir -p "$HOME/.davfs2" "${mountPoint}"
            chmod 700 "$HOME/.davfs2"
            printf '%s %s %s\n' "${url}" "${username}" "$(cat "${secretPath}")" > "$HOME/.davfs2/secrets"
            chmod 600 "$HOME/.davfs2/secrets"
            mount.davfs ${url} "${mountPoint}"
          }
          ncu() {
            umount "${mountPoint}"
          }
        '';
      };

  # Standalone home-manager module for a backend: davfs2 on Linux, rclone on
  # macOS (davfs2 is Linux-only).
  mkHomeModule =
    name: backend:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.${name} = mkOptions "$HOME/nextcloud";
      config = lib.mkIf config.modules.${name}.enable (mkNextcloudHome {
        inherit config lib pkgs;
        mountPoint = config.modules.${name}.mountPoint;
        inherit backend;
      });
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
    let
      mountPoint = config.modules.nextcloud.mountPoint;
      # systemd-escape of the mount point: /mnt/nextcloud -> mnt-nextcloud.mount
      mountUnit = "${builtins.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" mountPoint)}.mount";
      secretPath = config.sops.secrets.${secretName}.path;
    in
    {
      options.modules.nextcloud = mkOptions "/mnt/nextcloud";
      config = lib.mkIf config.modules.nextcloud.enable {
        # nixpkgs' davfs2 service: the davfs2 user+group and
        # /etc/davfs2/davfs2.conf.
        services.davfs2.enable = true;
        boot.kernelModules = [ "fuse" ];
        # sops decrypts the password to /run/secrets/NEXTCLOUD_PASSWORD (via the
        # sops activation script, which runs before multi-user.target).
        sops.secrets.${secretName} = {
          sopsFile = secretFile;
        };
        # Provision the system-wide credentials file that root/systemd
        # mount.davfs reads. `requiredBy`/`before` on the mount unit guarantees
        # it exists before any start of the mount — including systemd's own
        # restart during a switch after an fstab change.
        systemd.services.davfs2-secrets = {
          description = "Provision davfs2 credentials for the Nextcloud mount";
          wantedBy = [ "multi-user.target" ];
          before = [ mountUnit ];
          requiredBy = [ mountUnit ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.coreutils}/bin/install -d -m 0700 /etc/davfs2
            ${pkgs.coreutils}/bin/printf '%s %s %s\n' "${url}" "${username}" "$(cat "${secretPath}")" > /etc/davfs2/secrets
            ${pkgs.coreutils}/bin/chmod 0600 /etc/davfs2/secrets
          '';
        };
        # The mount point must exist before mount.davfs binds it — create it at
        # boot.
        systemd.tmpfiles.rules = [
          "d ${mountPoint} 0755 ${config.modules.users.userName} users -"
        ];
        # fstab entry for the systemd mount. systemd mounts it as root, so the
        # uid/gid/file_mode/dir_mode options present the davfs2 daemon's files
        # as owned by the user. `user` grants the user a passwordless
        # `systemctl start/stop` of the generated unit; `noauto` keeps it out of
        # the boot sequence — ncm mounts it on demand.
        fileSystems."${mountPoint}" = {
          device = url;
          fsType = "davfs";
          options = [
            "rw"
            "user"
            "noauto"
            "uid=${config.modules.users.userName}"
            "gid=users"
            "file_mode=0664"
            "dir_mode=0775"
          ];
        };
        home-manager.users.${config.modules.users.userName} = mkNextcloudHome {
          inherit
            config
            lib
            pkgs
            mountPoint
            ;
          backend = "systemd";
        };
      };
    };

  flake.modules.homeManager.nextcloud = mkHomeModule "nextcloud" "davfs";

  # macOS: davfs2 is Linux-only (FUSE), so mount via rclone + macFUSE instead.
  flake.modules.homeManager.nextcloudRclone = mkHomeModule "nextcloudRclone" "rclone";
}
