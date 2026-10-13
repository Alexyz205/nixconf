_: {
  nixconf.modules.nixos.youtubeMusic =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.youtubeMusic.enable = lib.mkEnableOption "YouTube Music desktop app (MPRIS)";
      config = lib.mkIf config.modules.youtubeMusic.enable {
        environment.systemPackages = [ pkgs.pear-desktop ];
      };
    };

  nixconf.modules.homeManager.youtubeMusic =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.youtubeMusic.enable = lib.mkEnableOption "YouTube Music desktop app (MPRIS)";
      config = lib.mkIf config.modules.youtubeMusic.enable {
        home.packages = [ pkgs.pear-desktop ];
      };
    };
}
