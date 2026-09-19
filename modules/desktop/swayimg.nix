_: {
  flake.modules.nixos.swayimg =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.swayimg.enable = lib.mkEnableOption "Swayimg (Wayland image viewer)";
      config = lib.mkIf config.modules.swayimg.enable {
        environment.systemPackages = [ pkgs.swayimg ];
      };
    };

  flake.modules.homeManager.swayimg =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.swayimg.enable = lib.mkEnableOption "Swayimg (Wayland image viewer)";
      config = lib.mkIf config.modules.swayimg.enable {
        home.packages = [ pkgs.swayimg ];
        xdg.mimeApps.defaultApplications = {
          "image/*" = [ "swayimg.desktop" ];
        };
      };
    };
}
