{
  inputs,
  self,
  ...
}: {
  perSystem = {pkgs, ...}: {
    packages.noctalia-shell = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
      inherit pkgs;

      settings = {
        bar = {
          position = "top";
          floating = false;
          exclusive = true;
          outerCorners = false;
          marginHorizontal = 0;
          marginVertical = 0;
          widgets = {
            left = [{id = "Workspace";}];
            center = [];
            right = [
              {id = "Volume";}
              {id = "Network";}
              {id = "Battery";}
              {id = "Clock";}
              {id = "Tray";}
            ];
          };
        };

        appLauncher = {
          position = "center";
          viewMode = "list";
          showCategories = true;
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
    };
  };

  flake.modules.nixos.noctalia = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.noctalia.enable = lib.mkEnableOption "Noctalia Shell bar";
    config = lib.mkIf config.modules.noctalia.enable {
      environment.systemPackages = [self.packages.${pkgs.system}.noctalia-shell];
    };
  };
}
