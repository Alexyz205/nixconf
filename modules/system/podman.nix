_: {
  flake.modules.nixos.podman =
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
      };
    };
}
