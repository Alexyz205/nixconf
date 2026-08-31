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
    # Point nix's git fetches at the system CA bundle when present, so
    # corporate / MITM CAs installed on the host are honoured (containers
    # behind TLS-intercepting proxies). macOS has no such path — left unset.
    ssl-cert-file = lib.mkIf (builtins.pathExists "/etc/ssl/certs/ca-certificates.crt") "/etc/ssl/certs/ca-certificates.crt";
  };
  trustedSettings = {
    auto-optimise-store = true;
    min-free = 134217728;
    max-free = 1000000000;
  };
in
{
  flake.modules.nixos.nix = { _ }: {
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
