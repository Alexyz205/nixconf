_:
let
  # Remmina is the GUI/connection manager, FreeRDP the engine and the
  # `xfreerdp`/`sdl-freerdp` command-line clients it links against.
  mkHomeCfg = pkgs: {
    home.packages = [
      pkgs.freerdp
      pkgs.remmina
    ];
    xdg.mimeApps.defaultApplications = {
      "application/x-rdp" = [ "org.remmina.Remmina.desktop" ];
      "x-scheme-handler/rdp" = [ "org.remmina.Remmina.desktop" ];
    };
  };
in
{
  nixconf.modules.nixos.rdp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.rdp.enable = lib.mkEnableOption "RDP client (Remmina + FreeRDP)";
      config = lib.mkIf config.modules.rdp.enable {
        environment.systemPackages = [
          pkgs.freerdp
          pkgs.remmina
        ];
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (
          _:
          {
            pkgs,
            ...
          }:
          mkHomeCfg pkgs
        );
      };
    };

  nixconf.modules.homeManager.rdp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.rdp.enable = lib.mkEnableOption "RDP client (Remmina + FreeRDP)";
      config = lib.mkIf config.modules.rdp.enable (mkHomeCfg pkgs);
    };
}
