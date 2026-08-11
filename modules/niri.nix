{
  inputs,
  self,
  ...
}: {
  perSystem = { pkgs, lib, self', ... }: {
    packages.niri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;

      settings = {
        prefer-no-csd = null;

        input = {
          focus-follows-mouse = null;
          keyboard = {
            xkb.layout = "us";
            xkb.options = "caps:escape";
            repeat-rate = 40;
            repeat-delay = 250;
          };
          touchpad = { natural-scroll = null; tap = null; };
          mouse.accel-profile = "flat";
        };

        binds = {
          "Mod+Return".spawn = lib.getExe pkgs.ghostty;
          "Mod+Q".close-window = null;
          "Mod+F".maximize-column = null;
          "Mod+G".fullscreen-window = null;
          "Mod+Shift+F".toggle-window-floating = null;
          "Mod+C".center-column = null;
          "Mod+H".focus-column-left = null;
          "Mod+L".focus-column-right = null;
          "Mod+K".focus-window-up = null;
          "Mod+J".focus-window-down = null;
          "Mod+Left".focus-column-left = null;
          "Mod+Right".focus-column-right = null;
          "Mod+Up".focus-window-up = null;
          "Mod+Down".focus-window-down = null;
          "Mod+Shift+H".move-column-left = null;
          "Mod+Shift+L".move-column-right = null;
          "Mod+Shift+K".move-window-up = null;
          "Mod+Shift+J".move-window-down = null;
          "Mod+1".focus-workspace = "1";
          "Mod+2".focus-workspace = "2";
          "Mod+3".focus-workspace = "3";
          "Mod+4".focus-workspace = "4";
          "Mod+5".focus-workspace = "5";
          "Mod+6".focus-workspace = "6";
          "Mod+7".focus-workspace = "7";
          "Mod+8".focus-workspace = "8";
          "Mod+9".focus-workspace = "9";
          "Mod+0".focus-workspace = "10";
          "Mod+Shift+1".move-column-to-workspace = "1";
          "Mod+Shift+2".move-column-to-workspace = "2";
          "Mod+Shift+3".move-column-to-workspace = "3";
          "Mod+Shift+4".move-column-to-workspace = "4";
          "Mod+Shift+5".move-column-to-workspace = "5";
          "Mod+Shift+6".move-column-to-workspace = "6";
          "Mod+Shift+7".move-column-to-workspace = "7";
          "Mod+Shift+8".move-column-to-workspace = "8";
          "Mod+Shift+9".move-column-to-workspace = "9";
          "Mod+Shift+0".move-column-to-workspace = "10";
          "Mod+S".spawn-sh = "${lib.getExe self'.packages.noctalia-shell} ipc call launcher toggle";
          "Mod+D".spawn-sh = lib.getExe pkgs.firefox;
          "XF86AudioRaiseVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          "Mod+Ctrl+H".set-column-width = "-5%";
          "Mod+Ctrl+L".set-column-width = "+5%";
          "Mod+Ctrl+J".set-window-height = "-5%";
          "Mod+Ctrl+K".set-window-height = "+5%";
          "Mod+WheelScrollDown".focus-column-left = null;
          "Mod+WheelScrollUp".focus-column-right = null;
          "Mod+Ctrl+WheelScrollDown".focus-workspace-down = null;
          "Mod+Ctrl+WheelScrollUp".focus-workspace-up = null;
          "Mod+Ctrl+S".spawn-sh = ''${lib.getExe pkgs.grim} -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy'';
        };

        layout = { gaps = 5; focus-ring = { width = 2; active-color = "#b8bb26"; }; };
        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
        spawn-at-startup = [ (lib.getExe self'.packages.noctalia-shell) ];
      };
    };
  };
}
