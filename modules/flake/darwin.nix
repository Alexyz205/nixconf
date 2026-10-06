{
  config,
  inputs,
  ...
}:
let
  features = config.flake.modules.darwin;
  # Flake-level overlays. The inner nix-darwin module shadows `config`, so bind
  # the flake config first.
  flakeOverlays = config.flake.modules.overlays;

  # Shared nix-darwin boilerplate: host identity + home-manager wiring that
  # every darwin host repeats. Keeps hosts to their deltas only.
  mkDarwinCommon =
    {
      hostName,
      systemStateVersion,
      homeStateVersion,
      userName,
      homeDirectory,
      hmModules ? [ ],
      hmSettings ? { },
    }:
    {
      lib,
      pkgs,
      ...
    }:
    {
      networking.hostName = hostName;
      system.stateVersion = systemStateVersion;
      system.primaryUser = userName;
      nixpkgs.overlays = flakeOverlays;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit (inputs) lazyvim;
        };
        users.${userName} = lib.mkMerge [
          {
            imports = hmModules ++ [ inputs.sops-nix.homeManagerModules.sops ];
            home = {
              username = userName;
              homeDirectory = lib.mkForce homeDirectory;
              stateVersion = homeStateVersion;
            };
            nix.package = lib.mkForce pkgs.nixVersions.latest;
          }
          hmSettings
        ];
      };
    };
in
{
  config.flake = {
    darwinFeatures = {
      # Everything the macOS hosts share: base system, nix, defaults, security,
      # Homebrew and fonts. Hosts add only their deltas.
      base = with features; [
        system
        nix
        defaults
        security
        homebrew
        fonts
      ];
    };
    inherit mkDarwinCommon;
  };
}
