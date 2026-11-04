_: {
  nixconf.modules.nixos.imv =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.imv.enable = lib.mkEnableOption "imv (image viewer)";
      config = lib.mkIf config.modules.imv.enable {
        environment.systemPackages = [ pkgs.imv ];
      };
    };

  nixconf.modules.homeManager.imv =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.imv.enable = lib.mkEnableOption "imv (image viewer)";
      config = lib.mkIf config.modules.imv.enable {
        home.packages = [ pkgs.imv ];
        xdg.mimeApps.defaultApplications = {
          "image/*" = [ "imv.desktop" ];
        };
      };
    };
}
