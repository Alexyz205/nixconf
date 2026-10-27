{ inputs, config, ... }:
{
  config = {
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];

    # Apply the flake's overlays (fetchgit CA wrapper, package fixes) to the
    # perSystem pkgs used by custom packages (niri, noctalia, ...) too,
    # not just the NixOS / home-manager pkgs. flake-parts' default perSystem
    # pkgs is mkOptionDefault'd, so a plain assignment wins.
    perSystem =
      {
        system,
        ...
      }:
      {
        _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system}.extend (
          inputs.nixpkgs.lib.composeManyExtensions config.nixconf.modules.overlays
        );
      };
  };

  options.nixconf.modules = {
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
    overlays = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.listOf inputs.nixpkgs.lib.types.raw;
      default = [ ];
    };
  };

  # Private namespace for internal helpers. Kept OFF `config.flake.*` so
  # flake-parts does not expose them as top-level flake outputs (which makes
  # `nix flake check` warn about unknown outputs).
  options.nixconf = {
    nixosFeatures = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.lazyAttrsOf (
        inputs.nixpkgs.lib.types.listOf inputs.nixpkgs.lib.types.raw
      );
      default = { };
    };
    darwinFeatures = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.lazyAttrsOf (
        inputs.nixpkgs.lib.types.listOf inputs.nixpkgs.lib.types.raw
      );
      default = { };
    };
    mkHostCommon = inputs.nixpkgs.lib.mkOption { type = inputs.nixpkgs.lib.types.raw; };
    mkDarwinCommon = inputs.nixpkgs.lib.mkOption { type = inputs.nixpkgs.lib.types.raw; };
    mkBtrfsLayout = inputs.nixpkgs.lib.mkOption { type = inputs.nixpkgs.lib.types.raw; };
  };
}
