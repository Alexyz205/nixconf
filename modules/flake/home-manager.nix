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
    yubikey
    devenv
    opencode
    btop
  ];

  mkHome = system: username: homeDirectory: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    extraSpecialArgs = {
      lazyvim = inputs.lazyvim;
    };
    modules =
      [
        {
          home = {
            inherit username homeDirectory;
            stateVersion = "24.11";
          };
          modules.packages = {
            basic = true;
            containers = true;
            devTools = true;
          };
          gtk.gtk4.theme = null;
        }
      ]
      ++ hmModules;
  };
in {
  flake.homeConfigurations = {
    "alexis@macos" = mkHome "aarch64-darwin" "alexis" "/Users/alexis";
    "alexis@linux" = mkHome "x86_64-linux" "alexis" "/home/alexis";
    "alexis.pigeon@RNSL-APIGEON5" = mkHome "x86_64-linux" "alexis.pigeon" "/home/alexis.pigeon";
  };
}
