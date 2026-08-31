{
  inputs,
  self,
  ...
}:
{
  perSystem = { pkgs, ... }: {
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
              { id = "Volume"; }
              { id = "Network"; }
              { id = "Battery"; }
              { id = "Clock"; }
              { id = "NotificationHistory"; }
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
          lockOnSuspend = true;
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
        };

        wallpaper = {
          enabled = false;
        };

        settingsVersion = 32;
      };

      colors = {
        mError = "#f38ba8";
        mOnError = "#1e1e2e";
        mOnPrimary = "#1e1e2e";
        mOnSecondary = "#1e1e2e";
        mOnSurface = "#cdd6f4";
        mOnSurfaceVariant = "#a6adc8";
        mOnTertiary = "#1e1e2e";
        mOutline = "#7f849c";
        mPrimary = "#cba6f7";
        mSecondary = "#a6adc8";
        mShadow = "#000000";
        mSurface = "#1e1e2e";
        mSurfaceVariant = "#313244";
        mTertiary = "#b4befe";
      };
    };
  };

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
