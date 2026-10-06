{ inputs, config, ... }:
{
  config = {
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];

    # Apply the flake's overlays (fetchgit CA wrapper, package fixes) to the
    # perSystem pkgs used by custom packages (niri, noctalia-shell, ...) too,
    # not just the NixOS / home-manager pkgs. flake-parts' default perSystem
    # pkgs is mkOptionDefault'd, so a plain assignment wins.
    perSystem =
      {
        system,
        ...
      }:
      {
        _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system}.extend (
          inputs.nixpkgs.lib.composeManyExtensions config.flake.modules.overlays
        );
      };
  };

  options.flake.modules = {
    nixos = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.lazyAttrsOf inputs.nixpkgs.lib.types.raw;
      default = { };
    };
    homeManager = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.lazyAttrsOf inputs.nixpkgs.lib.types.raw;
      default = { };
    };
    darwin = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.lazyAttrsOf inputs.nixpkgs.lib.types.raw;
      default = { };
    };
  };
}
