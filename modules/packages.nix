{ lib, ... }: {
  flake.modules.nixos.packages = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.packages = {
      basic = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      containers = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      security = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };

    config = {
      environment.systemPackages =
        with pkgs;
        (lib.optionals config.modules.packages.basic [
          curl
          wget
          openssl
        ])
        ++ (lib.optionals config.modules.packages.containers [
          devpod
          docker-compose
          podman-compose
        ])
        ++ (lib.optionals config.modules.packages.security [
          pass
          age
          sops
          gnupg
        ]);
    };
  };
}