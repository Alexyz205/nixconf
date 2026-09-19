_: {
  flake.modules.nixos.gimp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.gimp.enable = lib.mkEnableOption "GIMP (image editor)";
      config = lib.mkIf config.modules.gimp.enable {
        environment.systemPackages = [ pkgs.gimp ];
      };
    };

  flake.modules.homeManager.gimp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.gimp.enable = lib.mkEnableOption "GIMP (image editor)";
      config = lib.mkIf config.modules.gimp.enable {
        home.packages = [ pkgs.gimp ];
      };
    };
}
