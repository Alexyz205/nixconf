_: {
  flake.modules.darwin.nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.nix.enable = lib.mkEnableOption "Nix daemon settings on macOS";
      config = lib.mkIf config.modules.nix.enable {
        # Latest stable Nix for the daemon + CLI.
        nix.package = lib.mkForce pkgs.nixVersions.latest;
        nix.settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          substituters = [ "https://cache.nixos.org" ];
          # macOS has no @wheel; admin users are trusted instead.
          trusted-users = [
            "root"
            "@admin"
          ];
          max-jobs = "auto";
          cores = 0;
          connect-timeout = 5;
          keep-going = true;
          fallback = true;
          warn-dirty = false;
        };
        # auto-optimise-store is known to corrupt the Nix store on Darwin; the
        # supported replacement is the periodic optimise service instead.
        nix.optimise.automatic = true;
        nix.gc = {
          automatic = true;
          options = "--delete-older-than 30d";
        };
      };
    };
}
