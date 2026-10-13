_:
let
  palette = import ../../config/theme/catppuccin-mocha.nix;
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
          "${palette.blue}"
          "bold"
        ];
        inactiveBorderColor = [ "${palette.subtext0}" ];
        searchingActiveBorderColor = [ "${palette.yellow}" ];
        optionsTextColor = [ "${palette.blue}" ];
        selectedLineBgColor = [ "${palette.surface0}" ];
        inactiveViewSelectedLineBgColor = [ "${palette.overlay0}" ];
        cherryPickedCommitFgColor = [ "${palette.blue}" ];
        cherryPickedCommitBgColor = [ "${palette.surface1}" ];
        markedBaseCommitFgColor = [ "${palette.blue}" ];
        markedBaseCommitBgColor = [ "${palette.yellow}" ];
        unstagedChangesColor = [ "${palette.red}" ];
        defaultFgColor = [ "${palette.text}" ];
        # Moved under gui.theme in lazygit 0.66 (was gui.authorColors).
        authorColors = {
          "*" = "${palette.lavender}";
          Alexyz205 = "${palette.sapphire}";
          "Alexis Pigeon" = "${palette.sapphire}";
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
