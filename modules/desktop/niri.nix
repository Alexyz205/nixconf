{
  inputs,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    catppuccin = {
      surface0 = "#313244";
      mauve = "#cba6f7";
    };
    wallpaper = pkgs.nixos-artwork.wallpapers.catppuccin-mocha;

    # workspace "name" {} in declaration order (extraSettings preserves order,
    # unlike the `workspaces` option which sorts alphabetically).
    namedWorkspace = name: _: {
      props = name;
      content = {};
    };

    # bind with a hotkey-overlay-title so it shows up in niri's cheat sheet.
    hotkey = desc: content: _: {
      props."hotkey-overlay-title" = desc;
      content = content;
    };
    # workspace focus bind with a cheat-sheet entry.
    ws = name: hotkey "Workspace: ${name}" {focus-workspace = name;};
  in {
    packages.niri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;

      settings = {
        prefer-no-csd = _: {};
        debug.honor-xdg-activation-with-invalid-serial = _: {};

        input = {
          focus-follows-mouse = _: {};
          keyboard = {
            xkb.layout = "us";
            xkb.options = "caps:escape";
            repeat-rate = 40;
            repeat-delay = 250;
          };
          touchpad = {
            natural-scroll = _: {};
            tap = _: {};
          };
          mouse.accel-profile = "flat";
        };

        # Only binds that differ from niri's defaults get a hotkey-overlay-title;
        # the rest are stock keys that niri's built-in cheat sheet (Mod+Shift+/)
        # already shows. niri does NOT auto-apply default binds, so they must be
        # declared here.
        binds = {
          # Cheat sheet.
          "Mod+Shift+Slash".show-hotkey-overlay = _: {};

          # Launch.
          "Mod+T" = hotkey "Open a Terminal" {spawn = lib.getExe pkgs.ghostty;};
          "Mod+Return" = hotkey "Open a Terminal" {spawn = lib.getExe pkgs.ghostty;};
          "Mod+D" = hotkey "Run an Application" {
            spawn-sh = "${lib.getExe self'.packages.noctalia-shell} ipc call launcher toggle";
          };
          "Mod+S" = hotkey "Open Browser" {spawn-sh = lib.getExe pkgs.firefox;};
          "Mod+Ctrl+V" = hotkey "Clipboard history" {
            spawn-sh = "${lib.getExe self'.packages.noctalia-shell} ipc call launcher clipboard";
          };

          # Windows.
          "Mod+Q" = _: {
            props.repeat = false;
            content.close-window = _: {};
          };
          "Mod+O" = _: {
            props.repeat = false;
            content.toggle-overview = _: {};
          };

          "Mod+Left".focus-column-left = _: {};
          "Mod+Down".focus-window-down = _: {};
          "Mod+Up".focus-window-up = _: {};
          "Mod+Right".focus-column-right = _: {};
          "Mod+H".focus-column-left = _: {};
          "Mod+J".focus-window-down = _: {};
          "Mod+K".focus-window-up = _: {};
          "Mod+L".focus-column-right = _: {};

          "Mod+Ctrl+Left".move-column-left = _: {};
          "Mod+Ctrl+Down".move-window-down = _: {};
          "Mod+Ctrl+Up".move-window-up = _: {};
          "Mod+Ctrl+Right".move-column-right = _: {};
          "Mod+Ctrl+H".move-column-left = _: {};
          "Mod+Ctrl+J".move-window-down = _: {};
          "Mod+Ctrl+K".move-window-up = _: {};
          "Mod+Ctrl+L".move-column-right = _: {};

          "Mod+Home".focus-column-first = _: {};
          "Mod+End".focus-column-last = _: {};
          "Mod+Ctrl+Home".move-column-to-first = _: {};
          "Mod+Ctrl+End".move-column-to-last = _: {};

          "Mod+Shift+Left".focus-monitor-left = _: {};
          "Mod+Shift+Down".focus-monitor-down = _: {};
          "Mod+Shift+Up".focus-monitor-up = _: {};
          "Mod+Shift+Right".focus-monitor-right = _: {};
          "Mod+Shift+H".focus-monitor-left = _: {};
          "Mod+Shift+J".focus-monitor-down = _: {};
          "Mod+Shift+K".focus-monitor-up = _: {};
          "Mod+Shift+L".focus-monitor-right = _: {};

          "Mod+Shift+Ctrl+Left".move-column-to-monitor-left = _: {};
          "Mod+Shift+Ctrl+Down".move-column-to-monitor-down = _: {};
          "Mod+Shift+Ctrl+Up".move-column-to-monitor-up = _: {};
          "Mod+Shift+Ctrl+Right".move-column-to-monitor-right = _: {};
          "Mod+Shift+Ctrl+H".move-column-to-monitor-left = _: {};
          "Mod+Shift+Ctrl+J".move-column-to-monitor-down = _: {};
          "Mod+Shift+Ctrl+K".move-column-to-monitor-up = _: {};
          "Mod+Shift+Ctrl+L".move-column-to-monitor-right = _: {};

          "Mod+Page_Down".focus-workspace-down = _: {};
          "Mod+Page_Up".focus-workspace-up = _: {};
          "Mod+U".focus-workspace-down = _: {};
          "Mod+I".focus-workspace-up = _: {};

          "Mod+Ctrl+Page_Down".move-column-to-workspace-down = _: {};
          "Mod+Ctrl+Page_Up".move-column-to-workspace-up = _: {};
          "Mod+Ctrl+U".move-column-to-workspace-down = _: {};
          "Mod+Ctrl+I".move-column-to-workspace-up = _: {};

          "Mod+Shift+Page_Down".move-workspace-down = _: {};
          "Mod+Shift+Page_Up".move-workspace-up = _: {};
          "Mod+Shift+U".move-workspace-down = _: {};
          "Mod+Shift+I".move-workspace-up = _: {};

          # Column/workspace layout.
          "Mod+BracketLeft".consume-or-expel-window-left = _: {};
          "Mod+BracketRight".consume-or-expel-window-right = _: {};
          "Mod+Comma".consume-window-into-column = _: {};
          "Mod+Period".expel-window-from-column = _: {};

          "Mod+R".switch-preset-column-width = _: {};
          "Mod+Shift+R".switch-preset-column-width-back = _: {};
          "Mod+Ctrl+Shift+R".switch-preset-window-height = _: {};
          "Mod+Ctrl+R".reset-window-height = _: {};

          "Mod+F".maximize-column = _: {};
          "Mod+Shift+F".fullscreen-window = _: {};
          "Mod+M".maximize-window-to-edges = _: {};
          "Mod+Ctrl+F".expand-column-to-available-width = _: {};
          "Mod+C".center-column = _: {};
          "Mod+Ctrl+C".center-visible-columns = _: {};

          "Mod+Minus".set-column-width = "-10%";
          "Mod+Equal".set-column-width = "+10%";
          "Mod+Shift+Minus".set-window-height = "-10%";
          "Mod+Shift+Equal".set-window-height = "+10%";

          "Mod+V".toggle-window-floating = _: {};
          "Mod+Shift+V".switch-focus-between-floating-and-tiling = _: {};
          "Mod+W".toggle-column-tabbed-display = _: {};

          # Workspaces (digit binds, named so Mod+1 is always "main").
          "Mod+1" = ws "main";
          "Mod+2" = ws "browser";
          "Mod+3" = ws "3";
          "Mod+4" = ws "4";
          "Mod+5" = ws "5";
          "Mod+6" = ws "6";
          "Mod+7" = ws "7";
          "Mod+8" = ws "8";
          "Mod+9" = ws "9";
          "Mod+0" = ws "10";

          "Mod+Shift+1".move-column-to-workspace = "main";
          "Mod+Shift+2".move-column-to-workspace = "browser";
          "Mod+Shift+3".move-column-to-workspace = "3";
          "Mod+Shift+4".move-column-to-workspace = "4";
          "Mod+Shift+5".move-column-to-workspace = "5";
          "Mod+Shift+6".move-column-to-workspace = "6";
          "Mod+Shift+7".move-column-to-workspace = "7";
          "Mod+Shift+8".move-column-to-workspace = "8";
          "Mod+Shift+9".move-column-to-workspace = "9";
          "Mod+Shift+0".move-column-to-workspace = "10";

          # Wheel.
          "Mod+WheelScrollDown" = _: {
            props."cooldown-ms" = 150;
            content.focus-workspace-down = _: {};
          };
          "Mod+WheelScrollUp" = _: {
            props."cooldown-ms" = 150;
            content.focus-workspace-up = _: {};
          };
          "Mod+Ctrl+WheelScrollDown" = _: {
            props."cooldown-ms" = 150;
            content.move-column-to-workspace-down = _: {};
          };
          "Mod+Ctrl+WheelScrollUp" = _: {
            props."cooldown-ms" = 150;
            content.move-column-to-workspace-up = _: {};
          };

          "Mod+WheelScrollRight".focus-column-right = _: {};
          "Mod+WheelScrollLeft".focus-column-left = _: {};
          "Mod+Ctrl+WheelScrollRight".move-column-right = _: {};
          "Mod+Ctrl+WheelScrollLeft".move-column-left = _: {};

          "Mod+Shift+WheelScrollDown".focus-column-right = _: {};
          "Mod+Shift+WheelScrollUp".focus-column-left = _: {};
          "Mod+Ctrl+Shift+WheelScrollDown".move-column-right = _: {};
          "Mod+Ctrl+Shift+WheelScrollUp".move-column-left = _: {};

          # Screenshots.
          "Print".screenshot = _: {};
          "Ctrl+Print".screenshot-screen = _: {};
          "Alt+Print".screenshot-window = _: {};
          "Mod+Ctrl+S" = hotkey "Screenshot to clipboard" {
            spawn-sh = ''${lib.getExe pkgs.grim} -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy'';
          };

          # System.
          "Mod+Escape" = _: {
            props."allow-inhibiting" = false;
            content.toggle-keyboard-shortcuts-inhibit = _: {};
          };
          "Mod+Shift+E" = hotkey "Exit niri" {quit = _: {};};
          "Mod+Shift+Q" = _: {content.quit = _: {};};
          "Mod+Shift+P" = hotkey "Power off monitors" {power-off-monitors = _: {};};

          # Volume.
          "XF86AudioRaiseVolume" = _: {
            props."allow-when-locked" = true;
            content.spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+";
          };
          "XF86AudioLowerVolume" = _: {
            props."allow-when-locked" = true;
            content.spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-";
          };
          "XF86AudioMute" = _: {
            props."allow-when-locked" = true;
            content.spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          };
        };

        layout = {
          gaps = 5;
          always-center-single-column = _: {};
          background-color = "transparent";
          focus-ring = {
            width = 2;
            active-color = catppuccin.mauve;
            inactive-color = catppuccin.surface0;
          };
        };
        cursor.xcursor-size = 24;
        layer-rules = [
          {
            matches = [{namespace = "^swaybg$";}];
            place-within-backdrop = true;
          }
        ];
        window-rules = [
          {
            matches = [{app-id = "^firefox$";}];
            open-on-workspace = "browser";
          }
          {
            matches = [{}];
            geometry-corner-radius = 20.0;
            clip-to-geometry = true;
          }
        ];

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
        spawn-at-startup = [
          (lib.getExe self'.packages.noctalia-shell)
          [
            (lib.getExe pkgs.swaybg)
            "-i"
            "${wallpaper}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png"
            "-m"
            "fill"
          ]
        ];
      };

      extraSettings = [
        {workspace = namedWorkspace "main";}
        {workspace = namedWorkspace "browser";}
      ];
    };
  };

  flake.modules.nixos.niri = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.niri.enable = lib.mkEnableOption "Niri scrollable-tiling WM";
    config = lib.mkIf config.modules.niri.enable {
      programs.niri.enable = true;
      programs.niri.package = self.packages.${pkgs.system}.niri;
    };
  };
}
