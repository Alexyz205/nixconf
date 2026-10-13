{
  inputs,
  self,
  ...
}:
let
  palette = import ../../config/theme/catppuccin-mocha.nix;
in
{
  perSystem =
    { pkgs, system, ... }:
    if system == "x86_64-linux" then
      {
        packages.noctalia-shell = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
          inherit pkgs;

          settings = {
            bar = {
              barType = "simple";
              position = "top";
              enableExclusionZoneInset = true;
              outerCorners = false;
              marginHorizontal = 0;
              marginVertical = 0;
              widgets = {
                left = [
                  {
                    id = "Workspace";
                    labelMode = "name";
                    characterCount = 7;
                  }
                  { id = "SystemMonitor"; }
                ];
                center = [ ];
                right = [
                  {
                    id = "MediaMini";
                    hideMode = "hidden";
                  }
                  {
                    id = "Tray";
                    drawerEnabled = true;
                  }
                  { id = "NotificationHistory"; }
                  { id = "Volume"; }
                  { id = "Network"; }
                  { id = "Battery"; }
                  { id = "Clock"; }
                  { id = "ControlCenter"; }
                ];
              };
            };

            appLauncher = {
              position = "center";
              viewMode = "list";
              showCategories = true;
              overviewLayer = true;
              enableClipboardHistory = true;
            };

            controlCenter = {
              position = "close_to_bar_button";
              cards = [
                {
                  id = "profile-card";
                  enabled = true;
                }
                {
                  id = "shortcuts-card";
                  enabled = true;
                }
                {
                  id = "audio-card";
                  enabled = true;
                }
                {
                  id = "brightness-card";
                  enabled = true;
                }
                {
                  id = "weather-card";
                  enabled = true;
                }
              ];
            };

            general = {
              animationSpeed = 1;
              showScreenCorners = false;
              showSessionButtonsOnLockScreen = true;
              lockOnSuspend = false;
              dimmerOpacity = 0.15;
            };

            dock = {
              enabled = false;
            };

            notifications = {
              enabled = true;
              location = "top_right";
            };

            osd = {
              enabled = true;
              location = "bottom";
              autoHideMs = 3000;
            };

            sessionMenu = {
              position = "center";
              countdownDuration = 10000;
              enableCountdown = true;
              # Hibernate disabled: no resume config and swap < RAM, so
              # `systemctl hibernate` always fails. Keep the dead action out of
              # the menu.
              powerOptions = [
                {
                  action = "lock";
                  enabled = true;
                  keybind = "1";
                }
                {
                  action = "suspend";
                  enabled = true;
                  keybind = "2";
                }
                {
                  action = "hibernate";
                  enabled = false;
                  keybind = "3";
                }
                {
                  action = "reboot";
                  enabled = true;
                  keybind = "4";
                }
                {
                  action = "logout";
                  enabled = true;
                  keybind = "5";
                }
                {
                  action = "shutdown";
                  enabled = true;
                  keybind = "6";
                }
                {
                  action = "rebootToUefi";
                  enabled = true;
                  keybind = "7";
                }
              ];
            };

            wallpaper = {
              enabled = false;
            };

            # Leave this at the version the settings were authored at so
            # noctalia runs its schema migrations on load (several, e.g. v35,
            # v37, v45, touch the bar). Setting it to the app's current version
            # skips them and leaves the bar unconfigured. The store config is
            # read-only, so migrations apply in-memory each start (the
            # write-back is a logged no-op).
            settingsVersion = 32;
          };

          colors = {
            mError = palette.red;
            mOnError = palette.base;
            mOnPrimary = palette.base;
            mOnSecondary = palette.base;
            mOnSurface = palette.text;
            mOnSurfaceVariant = palette.subtext0;
            mOnTertiary = palette.base;
            mOutline = palette.overlay1;
            mPrimary = palette.mauve;
            mSecondary = palette.subtext0;
            mShadow = "#000000";
            mSurface = palette.base;
            mSurfaceVariant = palette.surface0;
            mTertiary = palette.lavender;
          };
        };
      }
    else
      { };

  flake.modules.nixos.noctalia =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.noctalia.enable = lib.mkEnableOption "Noctalia Shell bar";
      config = lib.mkIf config.modules.noctalia.enable {
        environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-shell ];
      };
    };
}
