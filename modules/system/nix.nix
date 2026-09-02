{ lib, ... }:
let
  # nixpkgs' fetchgit (nix-prefetch-git) assigns GIT_SSL_CAINFO without
  # `export`, so the builder's git never sees it and falls back to nixpkgs'
  # own cacert bundle — breaking builds behind corporate/MITM proxies that
  # serve a self-signed root. Point fetchgit at the host system bundle via
  # `gitConfigFile` (exported as GIT_CONFIG_GLOBAL by builder.sh) instead:
  # a static file, so no eval cycle, and a no-op where the path is absent
  # (macOS). Upstream: NixOS/nixpkgs#101119, NixOS/nix#12698.
  fetchgitGitConfig = final:
    final.writeText "fetchgit-gitconfig" (
      if final.stdenv.hostPlatform.isDarwin then
        ""
      else
        ''
          [http]
          	sslCAInfo = /etc/ssl/certs/ca-certificates.crt
        ''
    );
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
    # Keep 128 MiB free, start GC at 1 GiB free (byte literals for readability).
    min-free = 134217728;
    max-free = 1000000000;
  };
in
{
  # Overlays applied to every host/profile's pkgs. Shared through the flake
  # `modules` namespace (freeform raw attrset) and threaded into home-manager
  # and each nixosSystem's nixpkgs.overlays.
  flake.modules.overlays = [
    (final: prev: {
      fetchgit = prev.fetchgit.override {
        config = {
          gitConfigFile = fetchgitGitConfig final;
        };
      };
    })
  ];

  flake.modules.nixos.nix = _: {
    nix.settings =
      userSettings
      // trustedSettings
      // {
        allowed-users = [ "@wheel" ];
        trusted-users = [ "@wheel" ];
      };
  };

  flake.modules.homeManager.nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.nix.enable = lib.mkEnableOption "Nix settings";
      config = lib.mkIf config.modules.nix.enable {
        nix.package = pkgs.nix;
        nix.settings = userSettings;
      };
    };
}
