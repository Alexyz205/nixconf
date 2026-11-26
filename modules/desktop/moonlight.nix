_: {
  # Moonlight is the client; the Sunshine host runs on Windows.
  # See the work repo docs for the host-side setup and recommended
  # bitrate/codec settings. RDP (Remmina/FreeRDP) stays installed as a console
  # fallback for the same machine.
  nixconf.modules.nixos.moonlight =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.moonlight.enable = lib.mkEnableOption "Moonlight game-stream client";
      config = lib.mkIf config.modules.moonlight.enable {
        environment.systemPackages = [ pkgs.moonlight-qt ];
      };
    };

  nixconf.modules.homeManager.moonlight =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.moonlight.enable = lib.mkEnableOption "Moonlight game-stream client";
      config = lib.mkIf config.modules.moonlight.enable {
        home.packages = [ pkgs.moonlight-qt ];
      };
    };
}
