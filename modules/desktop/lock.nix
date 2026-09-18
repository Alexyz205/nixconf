{ ... }:
{
  flake.modules.nixos.lock =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.lock.enable = lib.mkEnableOption "Hyprlock lock screen + swayidle idle suspend";

      config = lib.mkIf config.modules.lock.enable {
        # hyprlock authenticates via PAM. The NixOS hyprland/hyprlock modules
        # wire this up, but niri does not, so without it unlocking always fails.
        security.pam.services.hyprlock = { };
        # Lock AFTER resume (not before suspend, see the swayidle comment above):
        # suspend.target is reached only once systemd-suspend.service has
        # finished, so this runs hyprlock in the user session right after waking.
        systemd.services.lock-after-resume =
          let
            userName = config.modules.users.userName;
          in
          {
            description = "Lock the session after resuming from suspend";
            after = [ "systemd-suspend.service" ];
            wantedBy = [ "suspend.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = userName;
              ExecStart = pkgs.writeShellScript "lock-after-resume" ''
                export XDG_RUNTIME_DIR="/run/user/$(id -u ${userName})"
                export WAYLAND_DISPLAY="wayland-1"
                # swayidle keeps its pre-suspend idle state across sleep, so after
                # resume its 30-min suspend timeout re-fires immediately and the
                # machine suspends again right after the user unlocks. Restarting
                # it makes the idle timer start counting from scratch.
                systemctl --user restart swayidle.service
                # niri may not have re-acquired the display when the service fires;
                # retry until hyprlock can actually connect and render.
                for i in $(seq 1 15); do
                    if ${pkgs.hyprlock}/bin/hyprlock --no-fade-in --immediate-render; then
                      exit 0
                    fi
                    sleep 1
                  done
                  exit 1
              '';
            };
          };
        home-manager.users.${config.modules.users.userName} = {
          # hyprlock is installed and configured via home-manager so stylix
          # themes it (stylix.targets.hyprlock auto-enables on Linux and fills
          # background path/color + input-field colors). The swayidle commands
          # use store paths, so no system-wide install is needed.
          #
          # --no-fade-in --immediate-render: hyprlock fades in from a transparent
          # surface, which flashes niri's red locked-session background (niri#808).
          programs.hyprlock = {
            enable = true;
            settings = {
              general = {
                hide_cursor = true;
                ignore_empty_input = true;
              };
              background = {
                # stylix sets path (the stylix.image wallpaper) and color; add a
                # blur so the lock backdrop is dimmed behind the greeting.
                blur_passes = 3;
                blur_size = 8;
              };
              input-field = {
                monitor = "";
                size = "300, 50";
                position = "0, -140";
                dots_center = true;
                fade_on_empty = false;
                outline_thickness = 3;
                rounding = 8;
                placeholder_text = "<span foreground=\"##a6adc8\">Type password...</span>";
                shadow_passes = 2;
              };
              label = [
                # Greeting (catppuccin mocha base text, JetBrains Mono like the rest).
                {
                  monitor = "";
                  text = "hello alexyz";
                  color = "rgb(cdd6f4)";
                  font_size = 42;
                  font_family = "JetBrainsMono Nerd Font";
                  position = "0, 180";
                  halign = "center";
                  valign = "center";
                }
                {
                  monitor = "";
                  text = "$TIME";
                  color = "rgb(cdd6f4)";
                  font_size = 30;
                  font_family = "JetBrainsMono Nerd Font";
                  position = "0, 60";
                  halign = "center";
                  valign = "center";
                }
                {
                  monitor = "";
                  text = "cmd[update:60000] date +\"%A, %d %B %Y\"";
                  color = "rgb(a6adc8)";
                  font_size = 16;
                  font_family = "JetBrainsMono Nerd Font";
                  position = "0, 15";
                  halign = "center";
                  valign = "center";
                }
              ];
            };
          };
          services.swayidle = {
            enable = true;
            timeouts = [
              # Lock after 15 min idle; suspend after 30 min idle.
              {
                timeout = 900;
                command = "${pkgs.hyprlock}/bin/hyprlock --no-fade-in --immediate-render";
              }
              {
                timeout = 1800;
                command = "${pkgs.systemd}/bin/systemctl suspend";
              }
            ];
            events = {
              # Lock on `systemctl lock` (and the Mod+X bind). Deliberately NO
              # before-sleep: swayidle holds a delay-lock inhibitor for as long
              # as the before-sleep command runs, so with hyprlock (long-running)
              # every `systemctl suspend` waits the full logind timeout and looks
              # like it only suspends after unlocking. The lock-after-resume
              # service below keeps the screen locked after waking instead.
              lock = "${pkgs.hyprlock}/bin/hyprlock --no-fade-in --immediate-render";
            };
          };
        };
      };
    };
}
