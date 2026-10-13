let
  zoxideCfg = {
    enable = true;
    enableZshIntegration = true;
  };
in
_: {
  nixconf.modules.nixos.zoxide =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.zoxide.enable = lib.mkEnableOption "Zoxide";
      config = lib.mkIf config.modules.zoxide.enable {
        environment.systemPackages = [ pkgs.zoxide ];
        home-manager.users.${config.modules.users.userName}.programs.zoxide = zoxideCfg;
      };
    };

  nixconf.modules.homeManager.zoxide =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.zoxide.enable = lib.mkEnableOption "Zoxide";
      config = lib.mkIf config.modules.zoxide.enable {
        programs.zoxide = zoxideCfg;
      };
    };
}
