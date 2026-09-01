let
  btopCfg =
    {
      pkgs,
      config,
      ...
    }:
    {
      programs.btop = {
        enable = true;
        package = pkgs.btop.override { cudaSupport = true; };
        settings = {
          theme_background = false;
          vim_keys = true;
          color_theme = "catppuccin_mocha";
          gpu_usage = true;
        };
      };
      home.file.".config/btop/themes/catppuccin_mocha.theme".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/btop/catppuccin_mocha.theme";
    };
in
_: {
  flake.modules.nixos.btop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.btop.enable = lib.mkEnableOption "Btop";
      config = lib.mkIf config.modules.btop.enable {
        environment.systemPackages = [
          (pkgs.btop.override { cudaSupport = true; })
        ];
        home-manager.users.${config.modules.users.userName} = btopCfg;
      };
    };

  flake.modules.homeManager.btop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.btop.enable = lib.mkEnableOption "Btop";
      config = lib.mkIf config.modules.btop.enable (btopCfg {
        inherit pkgs config lib;
      });
    };
}
