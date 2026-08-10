# Podman module: rootless containers (devcontainers / devpod).
# Enable with `modules.podman.enable = true`.
{ config, lib, ... }:

{
  options.modules.podman = {
    enable = lib.mkEnableOption "rootless podman";
  };

  config = lib.mkIf config.modules.podman.enable {
    # Load modules needed by rootless podman at boot, because
    # lockKernelModules (security module) forbids loading them later.
    boot.kernelModules = [ "overlay" "fuse" ];

    virtualisation.podman = {
      enable = true;
      # `docker` CLI maps to podman.
      dockerCompat = true;
      # /run/docker.sock -> podman socket, so docker tools & devpod work.
      dockerSocket.enable = true;
      # Reclaim disk from old images/volumes weekly.
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
}
