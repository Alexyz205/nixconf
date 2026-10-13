_:
let
  tvCfg =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.television ];
      home.file.".config/television".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/television";
    };
in
{
  nixconf.modules.nixos.tv =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.tv.enable = lib.mkEnableOption "Television (tv) fuzzy finder";
      config = lib.mkIf config.modules.tv.enable {
        environment.systemPackages = [ pkgs.television ];
        home-manager.users.${config.modules.users.userName} = tvCfg;
      };
    };

  nixconf.modules.homeManager.tv =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.tv.enable = lib.mkEnableOption "Television (tv) fuzzy finder";
      config = lib.mkIf config.modules.tv.enable (tvCfg {
        inherit config pkgs;
      });
    };
}
