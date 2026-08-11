{ lib, ... }: {
  flake.modules.nixos.podman = { ... }: {
    boot.kernelModules = [ "overlay" "fuse" ];
    virtualisation.podman = { enable = true; dockerCompat = true; dockerSocket.enable = true; autoPrune = { enable = true; dates = "weekly"; }; };
  };
}
