{
  description = "Dendritic NixOS configuration: flake-parts + import-tree + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:GoByeBye/claude-desktop-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pin opencode to a working build. nixpkgs' opencode 1.18.30 crashes on
    # every prompt ("TypeError: undefined is not an object (evaluating
    # 'a.name')" in SystemPrompt.environment — anomalyco/opencode#49158); the
    # fix is upstream. This rev (d2f6794) ships 1.18.25, the last good build.
    # Revert once nixpkgs ships a fixed opencode.
    nixpkgs-opencode.url = "github:NixOS/nixpkgs/d2f67949798825fe853f7c5d0492b8bf016d3f88";

    # nixpkgs master rev carrying the devenv fix (libghostty-vt
    # 0.1.0-unstable-2026-08-06, NixOS/nixpkgs#563205). nixos-unstable's
    # devenv 2.3.1 links an ABI-incompatible libghostty-vt, so `devenv shell`
    # dies with "terminal error: invalid value" (cachix/devenv#3183). We take
    # the prebuilt devenv from this rev until nixos-unstable catches up.
    nixpkgs-devenv.url = "github:NixOS/nixpkgs/53ac6b7b63ad326e1e84105c306d5c9072f9d304";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
