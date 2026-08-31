{ lib, ... }: {
  flake.modules.nixos.podman = { ... }: {
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
}
