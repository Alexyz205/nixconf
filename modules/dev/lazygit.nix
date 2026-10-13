_:
let
  lazygitAliases = {
    lg = "lazygit";
  };
  homeCfg = {
    programs.lazygit = lazygitCfg;
    programs.zsh.shellAliases = lazygitAliases;
  };
  lazygitCfg = {
    enable = true;
    settings = {
      gui.theme = {
        activeBorderColor = [
          "#89b4fa"
          "bold"
        ];
        inactiveBorderColor = [ "#a6adc8" ];
        searchingActiveBorderColor = [ "#f9e2af" ];
        optionsTextColor = [ "#89b4fa" ];
        selectedLineBgColor = [ "#313244" ];
        inactiveViewSelectedLineBgColor = [ "#6c7086" ];
        cherryPickedCommitFgColor = [ "#89b4fa" ];
        cherryPickedCommitBgColor = [ "#45475a" ];
        markedBaseCommitFgColor = [ "#89b4fa" ];
        markedBaseCommitBgColor = [ "#f9e2af" ];
        unstagedChangesColor = [ "#f38ba8" ];
        defaultFgColor = [ "#cdd6f4" ];
        # Moved under gui.theme in lazygit 0.66 (was gui.authorColors).
        authorColors = {
          "*" = "#b4befe";
          Alexyz205 = "#74c7ec";
          "Alexis Pigeon" = "#74c7ec";
        };
      };
      git.diffRenderers = [
        {
          colorArg = "always";
          command = "delta --paging=never";
        }
      ];
    };
  };
in
{
  flake.modules.nixos.lazygit =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.lazygit.enable = lib.mkEnableOption "Lazygit";
      config = lib.mkIf config.modules.lazygit.enable {
        environment.systemPackages = [ pkgs.lazygit ];
        home-manager.users.${config.modules.users.userName} =
          homeCfg
          // lib.optionalAttrs (config ? stylix) {
            # We ship our own catppuccin theme; stylix's lazygit target would
            # concat its gui.theme color lists onto ours (home-manager list
            # merge), producing doubled/duplicated colors. Same guard as
            # yazi/starship/bat.
            stylix.targets.lazygit.enable = false;
          };
      };
    };

  flake.modules.homeManager.lazygit =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.lazygit.enable = lib.mkEnableOption "Lazygit";
      config = lib.mkIf config.modules.lazygit.enable (
        homeCfg
        // {
          home.packages = [ pkgs.lazygit ];
        }
      );
    };
}
