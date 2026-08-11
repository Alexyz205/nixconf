{lib, ...}: let
  lazygitCfg = {
    enable = true;
    settings = {
      gui.theme = {
        activeBorderColor = ["#89b4fa" "bold"];
        inactiveBorderColor = ["#a6adc8"];
        searchingActiveBorderColor = ["#f9e2af"];
        optionsTextColor = ["#89b4fa"];
        selectedLineBgColor = ["#313244"];
        inactiveViewSelectedLineBgColor = ["#6c7086"];
        cherryPickedCommitFgColor = ["#89b4fa"];
        cherryPickedCommitBgColor = ["#45475a"];
        markedBaseCommitFgColor = ["#89b4fa"];
        markedBaseCommitBgColor = ["#f9e2af"];
        unstagedChangesColor = ["#f38ba8"];
        defaultFgColor = ["#cdd6f4"];
      };
      gui.authorColors = {
        "*" = "#b4befe";
        Alexyz205 = "#74c7ec";
        "Alexis Pigeon" = "#74c7ec";
      };
      git.diffRenderers = [
        {
          colorArg = "always";
          command = "delta --paging=never";
        }
      ];
    };
  };
in {
  flake.modules.nixos.lazygit = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.lazygit.enable = lib.mkEnableOption "Lazygit";
    config = lib.mkIf config.modules.lazygit.enable {
      home-manager.users."alexis.pigeon".programs.lazygit = lazygitCfg;
    };
  };

  flake.modules.homeManager.lazygit = {...}: {
    programs.lazygit = lazygitCfg;
  };
}
