{
  inputs,
  config,
  lib,
  ...
}: let
  hmModules = with config.flake.modules.homeManager; [
    packages
    nix
    shell
    git
    bat
    eza
    zoxide
    starship
    tmux
    yazi
    lazygit
    ghostty
    lazyvim
  ];

  mkHome = system: homeDirectory: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    extraSpecialArgs = {
      lazyvim = inputs.lazyvim;
    };
    modules =
      [
        {
          home = {
            username = "alexis";
            inherit homeDirectory;
            stateVersion = "24.11";
          };
          modules.packages = {
            basic = true;
            containers = true;
            devTools = true;
          };
        }
      ]
      ++ hmModules;
  };
in {
  flake.homeConfigurations = {
    "alexis@macos" = mkHome "aarch64-darwin" "/Users/alexis";
    "alexis@linux" = mkHome "x86_64-linux" "/home/alexis";
  };
}
