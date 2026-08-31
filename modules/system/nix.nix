{ lib, ... }:
let
  userSettings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://cache.nixos.org" ];
    max-jobs = "auto";
    cores = 0;
    connect-timeout = 5;
    keep-going = true;
    fallback = true;
    warn-dirty = false;
  };
  trustedSettings = {
    auto-optimise-store = true;
    min-free = 134217728;
    max-free = 1000000000;
  };
in
{
  flake.modules.nixos.nix = { ... }: {
    nix.settings =
      userSettings
      // trustedSettings
      // {
        allowed-users = [ "@wheel" ];
        trusted-users = [ "@wheel" ];
      };
  };

  flake.modules.homeManager.nix = { pkgs, ... }: {
    nix.package = pkgs.nix;
    nix.settings = userSettings;
  };
}
