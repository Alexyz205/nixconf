{
  inputs,
  config,
  lib,
  ...
}: {
  flake.homeConfigurations."alexis.pigeon" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    extraSpecialArgs = {
      lazyvim = inputs.lazyvim;
    };
    modules =
      [
        ./../../packages.nix
        {
          home = {
            username = "alexis.pigeon";
            homeDirectory = "/home/alexis.pigeon";
            stateVersion = "24.11";
          };
        }
      ]
      ++ (with config.flake.modules.homeManager; [
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
      ]);
  };
}
