{
  config,
  lib,
  ...
}:
let
  url = "https://nextcloud.alexyz.org/remote.php/dav/files/alexyz";
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
    else
      let
        # NixOS: let mount(8) resolve the fstab entry and run the setuid
        # mount.davfs helper with the user-mount options (noexec, ...). It finds
        # the helper via its own search path (not the shell PATH), so calling
        # mount.davfs directly would hit the non-setuid copy instead.
        # Standalone: call the distro's setuid mount.davfs with the explicit URL.
        mountCmd = if fstabMount then "mount \"${mountPoint}\"" else "mount.davfs ${url} \"${mountPoint}\"";
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
            ${mountCmd}
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
        fstabMount = false;
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
    {
      options.modules.nextcloud = mkOptions "/mnt/nextcloud";
      config = lib.mkIf config.modules.nextcloud.enable {
        # nixpkgs' davfs2 service: setuid mount.davfs/umount.davfs wrappers,
        # the davfs2 user+group and /etc/davfs2/davfs2.conf.
        services.davfs2.enable = true;
        # Widen the setuid wrapper to world-executable: davfs2's group check
        # (check_permissions) is the real enforcement, and it reports a clear
        # "user must be member of group davfs2" instead of a cryptic EACCES
        # when the mounting session lacks the davfs2 group.
        security.wrappers."mount.davfs" = {
          permissions = lib.mkForce "u+rx,g+x,o+x";
        };
        boot.kernelModules = [ "fuse" ];
        # ... and the mounting user must be a member of the davfs2 group
        # (required by mount.davfs' setuid permission check).
        users.users.${config.modules.users.userName}.extraGroups = [ "davfs2" ];
        sops.secrets.${secretName} = {
          sopsFile = secretFile;
        };
        # The mount point must exist and be owned by the user so the setuid
        # mount.davfs can bind it — create it at boot.
        systemd.tmpfiles.rules = [
          "d ${config.modules.nextcloud.mountPoint} 0755 ${config.modules.users.userName} users -"
        ];
        # fstab entry for the setuid user mount: mount.davfs refuses non-root
        # mounts without a matching entry (check_fstab). `noauto` keeps it out
        # of the boot sequence — ncm mounts it on demand.
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

  flake.modules.homeManager.nextcloud = mkHomeModule "nextcloud" "davfs";

  # macOS: davfs2 is Linux-only (FUSE), so mount via rclone + macFUSE instead.
  flake.modules.homeManager.nextcloudRclone = mkHomeModule "nextcloudRclone" "rclone";
}
