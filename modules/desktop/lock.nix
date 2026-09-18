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

        home-manager.users.${config.modules.users.userName} =
          let
            hyprlock = "${lib.getExe pkgs.hyprlock} --no-fade-in --immediate-render";
            niri = lib.getExe pkgs.niri;
            systemctl = lib.getExe' pkgs.systemd "systemctl";
            loginctl = lib.getExe' pkgs.systemd "loginctl";

            # The scripts run from swayidle's systemd user service, whose PATH
            # home-manager overrides to bash only, so every bare command used
            # below (seq/sleep/touch/rm/awk/pgrep) must resolve explicitly. The
            # hyprlock/systemd/niri binaries are absolute store paths and need
            # no PATH.
            scriptPath = lib.makeBinPath [
              pkgs.coreutils
              pkgs.procps
              pkgs.gawk
              pkgs.systemd
              pkgs.niri
              pkgs.hyprlock
            ];

            # "Locked" = logind's LockedHint for this session. XDG_SESSION_ID
            # isn't reliably inherited by systemd user services (swayidle's),
            # so discover the seat session at runtime; pgrep is the final
            # fallback and also catches hyprlock the instant it spawns, before
            # logind catches up.
            lockedCheck = ''
              locked() {
                local s hint
                if [ -n "''${XDG_SESSION_ID:-}" ]; then
                  s="$XDG_SESSION_ID"
                else
                  s="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="''${USER:-}" '$3 == u && $4 != "" { print $1; exit }')"
                  [ -n "$s" ] || s="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="''${USER:-}" '$3 == u { print $1; exit }')"
                fi
                hint="$(loginctl show-session "$s" -p LockedHint --value 2>/dev/null)"
                [ "$hint" = "yes" ] || pgrep -x hyprlock >/dev/null 2>&1
              }
            '';

            # Single lock entry point: backgrounds hyprlock and waits (bounded)
            # for the lock to be up, so a suspend can never race ahead of the
            # lock screen. Exits 2 if a lock screen is already showing, 1 if
            # the lock never materialised within the wait.
            #
            # The guard is process-based (not LockedHint) on purpose: the
            # swayidle `lock` event fires as soon as logind reports the session
            # locked — e.g. right after `systemctl lock` (the Mod+X bind) or
            # before suspend — when hyprlock hasn't spawned yet, and that event
            # IS the trigger to spawn it.
            lockScript = pkgs.writeShellScript "niri-lock-screen" ''
              set -u
              PATH="${scriptPath}:''${PATH:-}"

              ${lockedCheck}

              pgrep -x hyprlock >/dev/null 2>&1 && exit 2

              ${hyprlock} &
              disown 2>/dev/null || true

              # Bounded wait for the lock to take effect (3s max, 50ms granularity).
              for _ in $(seq 1 60); do
                locked && exit 0
                sleep 0.05
              done

              # The lock never took effect: report it instead of pretending
              # success (swayidle logs the non-zero exit; the delay inhibitor
              # was still released, so this is observability, not a blocker).
              exit 1
            '';

            # Lock the screen on idle and schedule the power-off + suspend.
            #
            # The suspend must NOT be a swayidle timeout: niri buffers idle
            # events while an ext-session-lock is held and only flushes them on
            # unlock, so a `timeout 1800 systemctl suspend` fires the instant
            # you type your password and the machine sleeps in your face.
            # Scheduling the suspend here (15 min after the lock) is
            # deterministic and independent of idle events; the guard still
            # requires the session to be locked, so an early unlock cancels it.
            idleLockScript = pkgs.writeShellScript "niri-idle-lock" ''
              set -u
              PATH="${scriptPath}:''${PATH:-}"

              ${lockedCheck}

              lockPending="''${XDG_RUNTIME_DIR:-/tmp}/niri-idle-suspend.pending"

              ${lockScript}
              case $? in
                0) ;;
                2) exit 0 ;; # already locked, don't stack a suspend
                *) exit 1 ;;
              esac

              [ -e "$lockPending" ] && exit 0
              touch "$lockPending"

              # Power off monitors shortly after locking (niri wakes them on activity).
              ( sleep 5; locked && ${niri} msg action power-off-monitors ) &
              # Suspend 15 min after the lock, only while the session is still locked.
              ( sleep 900; rm -f "$lockPending"; locked && ${systemctl} suspend ) &
              disown 2>/dev/null || true
              exit 0
            '';
          in
          {
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
                # Lock after 15 min idle; the lock script schedules the monitor
                # power-off and the 30-min suspend (see niri-idle-lock above).
                {
                  timeout = 900;
                  command = "${idleLockScript}";
                }
              ];
              events = {
                # Lock before ANY sleep (idle suspend, power key, lid close) and on
                # `systemctl lock` / loginctl lock-session (the Mod+X bind). The
                # lock script backgrounds hyprlock and waits <=3s for it to be up,
                # so swayidle's delay inhibitor (held while before-sleep runs)
                # never stalls a suspend. The Mod+X bind is the niri module's
                # `systemctl lock`, so manual and idle lock share this path.
                before-sleep = "${lockScript}";
                lock = "${lockScript}";
                # The monitors were powered off by the idle lock; wake them on resume.
                after-resume = "${niri} msg action power-on-monitors";
              };
            };
          };
      };
    };
}
