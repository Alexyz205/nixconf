{ inputs, lib, ... }:
{
  imports = [ inputs.flake-file.flakeModules.default ];

  flake-file = {
    description = "Dendritic NixOS configuration: flake-parts + import-tree + home-manager";

    # Literal expression placed verbatim as `outputs` in the generated flake.nix.
    outputs = "inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } { imports = [ inputs.flake-parts.flakeModules.touchup { touchup.attr.formatter.enable = false; } ] ++ (inputs.import-tree ./modules { }).imports; }";

    # Core inputs only. Every other input is declared by the feature module that
    # consumes it (e.g. sops-nix in modules/system/sops.nix, stylix in the
    # workstation) and collected into flake.nix by `nix run .#write-flake`.
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

      flake-file.url = lib.mkDefault "github:denful/flake-file";

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };
      import-tree.url = "github:vic/import-tree";
    };
  };
}
