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

    # Stylix already themes GTK/Qt/terminals declaratively, so Noctalia must not
    # rewrite those same app configs behind its back.
    [theme.templates]
    enable_builtin_templates = false
    enable_community_templates = false
    builtin_ids = []
    community_ids = []

    [shell]
    clipboard_enabled = true
    clipboard_history_max_entries = 100

    [bar.default]
    position = "top"
    enabled = true
    reserve_space = true
    margin_ends = 0
    margin_edge = 0
    radius = 0
    concave_edge_corners = false
    start = ["workspaces", "sysmon"]
    end = ["media", "tray", "notifications", "volume", "network", "clock", "control-center"]

    # Both hosts are desktops: no system battery (power tab: charge, profiles,
    # peripheral batteries) and no controllable display backlight (monitor
    # tab: brightness), so drop both instead of leaving empty tabs behind.
    [control_center]
    hidden_tabs = ["power", "monitor"]

    [dock]
    enabled = false

    [wallpaper]
    enabled = false

    [backdrop]
    enabled = false

    # Approximate coordinates from the public IP; weather uses the same source.
    [location]
    auto_locate = true

    [weather]
    enabled = true
    refresh_minutes = 30
    unit = "metric"
    effects = false

    # Floating desktop widgets. Coordinates are logical pixels on the primary
    # monitor; omit `output` so the first available monitor is used on both
    # hosts. Cards share Catppuccin surface roles with the bar/panels.
    [desktop_widgets]
    enabled = true
    schema_version = 2
    widget_order = [
      "clock_main",
      "weather_main",
      "calendar_main",
      "sysmon_main",
      "media_main",
      "audio_main",
    ]

    [desktop_widgets.grid]
    visible = false
    cell_size = 16
    major_interval = 4

    [desktop_widgets.widget.clock_main]
    type = "clock"
    cx = 260.0
    cy = 190.0
    box_width = 0.0
    box_height = 0.0
    rotation = 0.0

    [desktop_widgets.widget.clock_main.settings]
    clock_style = "digital"
    format = "{:%H:%M}"
    center_text = true
    background = true
    background_color = "surface_container"
    background_opacity = 0.72
    background_radius = 22.0
    background_padding = 18.0
    color = "primary"
    shadow = true

    [desktop_widgets.widget.weather_main]
    type = "weather"
    cx = 260.0
    cy = 410.0
    box_width = 0.0
    box_height = 0.0
    rotation = 0.0

    [desktop_widgets.widget.weather_main.settings]
    show_forecast = true
    forecast_days = 3
    background = true
    background_color = "surface_container"
    background_opacity = 0.72
    background_radius = 22.0
    background_padding = 16.0
    color = "on_surface"
    shadow = true

    [desktop_widgets.widget.calendar_main]
    type = "calendar"
    cx = 3070.0
    cy = 320.0
    box_width = 0.0
    box_height = 0.0
    rotation = 0.0

    [desktop_widgets.widget.calendar_main.settings]
    show_events = true
    show_week_numbers = false
    show_events_location = false
    background = true
    background_color = "surface_container"
    background_opacity = 0.72
    background_radius = 22.0
    background_padding = 16.0

    [desktop_widgets.widget.sysmon_main]
    type = "sysmon"
    cx = 280.0
    cy = 1290.0
    box_width = 0.0
    box_height = 0.0
    rotation = 0.0

    [desktop_widgets.widget.sysmon_main.settings]
    display = "graph"
    stat = "cpu_usage"
    stat2 = "cpu_temp"
    color = "primary"
    color2 = "secondary"
    show_label = true
    shadow = true
    background = true
    background_color = "surface_container"
    background_opacity = 0.72
    background_radius = 22.0
    background_padding = 14.0

    [desktop_widgets.widget.media_main]
    type = "media_player"
    cx = 3060.0
    cy = 1280.0
    box_width = 0.0
    box_height = 0.0
    rotation = 0.0

    [desktop_widgets.widget.media_main.settings]
    layout = "horizontal"
    album_art_background = true
    album_art_blur = 32
    audio_visualizer = false
    hide_when_no_media = true
    background = true
    background_color = "surface_container"
    background_opacity = 0.72
    background_radius = 22.0
    background_padding = 16.0
    color = "on_surface"
    shadow = true

    [desktop_widgets.widget.audio_main]
    type = "audio_visualizer"
    cx = 1720.0
    cy = 1350.0
    box_width = 900.0
    box_height = 90.0
    rotation = 0.0

    [desktop_widgets.widget.audio_main.settings]
    bands = 48
    mirrored = true
    centered = true
    show_wave = true
    show_when_idle = false
    color_1 = "primary"
    color_2 = "secondary"
    background = false
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
      options.modules.noctalia = {
        enable = lib.mkEnableOption "Noctalia Shell bar";
        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ config.modules.users.userName ];
          description = "Users that receive the Noctalia bar configuration.";
        };
      };
      config = lib.mkIf config.modules.noctalia.enable {
        environment.systemPackages = [ pkgs.noctalia ];
        home-manager.users = lib.genAttrs config.modules.noctalia.users (_: {
          xdg.configFile."noctalia/config.toml".text = noctaliaConfig;
        });
      };
    };
}
