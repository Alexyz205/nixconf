_:
let
  # Noctalia v5 reads TOML from ~/.config/noctalia. v4 JSON settings do not
  # migrate, so this is a fresh config on the v5 schema. Niri renders the
  # wallpaper via swaybg, so Noctalia's wallpaper/backdrop stay off.
  noctaliaConfig = ''
    [theme]
    mode = "dark"
    shell_mode = "dark"
    source = "builtin"
    builtin = "Catppuccin"

    [bar.default]
    position = "top"
    enabled = true
    reserve_space = true
    margin_ends = 0
    margin_edge = 0
    radius = 0
    concave_edge_corners = false
    start = ["workspaces", "sysmon"]
    end = ["media", "tray", "notifications", "volume", "network", "battery", "clock", "control-center"]

    [dock]
    enabled = false

    [wallpaper]
    enabled = false

    [backdrop]
    enabled = false
  '';
in
{
  nixconf.modules.nixos.noctalia =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.noctalia.enable = lib.mkEnableOption "Noctalia Shell bar";
      config = lib.mkIf config.modules.noctalia.enable {
        environment.systemPackages = [ pkgs.noctalia ];
        home-manager.users.${config.modules.users.userName} = {
          xdg.configFile."noctalia/config.toml".text = noctaliaConfig;
        };
      };
    };
}
