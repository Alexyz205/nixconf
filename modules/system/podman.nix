_: {
  nixconf.modules.nixos.podman =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.podman.enable = lib.mkEnableOption "Podman container runtime (docker-compatible)";
      config = lib.mkIf config.modules.podman.enable {
        boot.kernelModules = [
          "overlay"
          "fuse"
          # Rootless pasta/slirp4netns networking needs /dev/net/tun.
          "tun"
        ];
        virtualisation.podman = {
          enable = true;
          dockerCompat = true;
          dockerSocket.enable = true;
          autoPrune = {
            enable = true;
            dates = "weekly";
          };
        };
        # Corp images built from AD/idmap-mounted trees carry UIDs no subuid
        # range can map (e.g. 1755687193:1755600513 in dxyzsdk), so rootless
        # unpack dies with "potentially insufficient UIDs or GIDs". Squash
        # unmapped IDs to the calling user instead of failing the pull.
        # Rootless-only: rootful can chown arbitrary numeric IDs.
        virtualisation.containers.storage.rootless.settings.storage.options.overlay.ignore_chown_errors =
          "true";
      };
    };
}
