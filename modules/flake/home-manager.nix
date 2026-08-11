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
        {
          home = {
            username = "alexis.pigeon";
            homeDirectory = "/home/alexis.pigeon";
            stateVersion = "24.11";
          };
        }
      ]
      ++ (with config.flake.modules.homeManager; [
        packages
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
      ])
      ++ [{
        modules.packages = {
          basic = true;
          containers = true;
          devTools = true;
        };
      }];
  };
}
