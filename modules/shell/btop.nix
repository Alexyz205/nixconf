let
  btopCfg = {
    pkgs,
    config,
    lib,
    ...
  }: {
    programs.btop = {
      enable = true;
      settings = {
        theme_background = false;
        vim_keys = true;
        color_theme = "catppuccin_mocha";
      };
    };
    home.file.".config/btop/themes/catppuccin_mocha.theme".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/btop/catppuccin_mocha.theme";
  };
in
  {lib, ...}: {
    flake.modules.nixos.btop = {
      config,
      lib,
      pkgs,
      ...
    }: {
      options.modules.btop.enable = lib.mkEnableOption "Btop";
      config = lib.mkIf config.modules.btop.enable {
        environment.systemPackages = [pkgs.btop];
        home-manager.users.${config.modules.users.userName} = btopCfg;
      };
    };

    flake.modules.homeManager.btop = btopCfg;
  }
