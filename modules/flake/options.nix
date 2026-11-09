{ inputs, config, ... }:
let
  lib = inputs.nixpkgs.lib;
in
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
          lib.composeManyExtensions config.nixconf.modules.overlays
        );
      };
  };

  options.nixconf = {
    modules = {
      nixos = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
      };
      homeManager = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
      };
      darwin = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
      };
      overlays = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
      };
    };

    # Single source of truth for unfree packages. Both the NixOS hosts and the
    # standalone home-manager profiles use `nixconf.allowUnfreePredicate`, so a
    # new unfree package is allowed everywhere at once instead of drifting
    # between per-host allowUnfreePredicate lists.
    unfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "brave"
        "claude-desktop"
        "steam"
        "steam-unwrapped"
        "vesktop"
        "nvidia-x11"
        "nvidia-settings"
      ];
      description = "Package names allowed through nixpkgs' unfree check on every host and profile.";
    };
    allowUnfreePredicate = lib.mkOption {
      type = lib.types.raw;
      default =
        pkg:
        builtins.elem (lib.getName pkg) config.nixconf.unfreePackages
        || builtins.any (license: license == lib.licenses.nvidiaCudaRedist) (
          lib.lists.toList (pkg.meta.license or [ ])
        );
      description = "Predicate installed as nixpkgs.config.allowUnfreePredicate.";
    };

    # Private namespace for internal helpers. Kept OFF `config.flake.*` so
    # flake-parts does not expose them as top-level flake outputs (which makes
    # `nix flake check` warn about unknown outputs).
    nixosFeatures = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.listOf lib.types.raw);
      default = { };
    };
    darwinFeatures = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.listOf lib.types.raw);
      default = { };
    };
    mkHostCommon = lib.mkOption { type = lib.types.raw; };
    mkDarwinCommon = lib.mkOption { type = lib.types.raw; };
    mkBtrfsLayout = lib.mkOption { type = lib.types.raw; };
  };
}
