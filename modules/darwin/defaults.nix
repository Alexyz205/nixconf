_: {
  flake.modules.darwin.defaults =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.defaults.enable = lib.mkEnableOption "macOS system defaults";
      config = lib.mkIf config.modules.defaults.enable {
        system.defaults = {
          NSGlobalDomain = {
            AppleInterfaceStyle = "Dark";
            AppleInterfaceStyleSwitchesAutomatically = false;
            AppleShowAllExtensions = true;
            ApplePressAndHoldEnabled = false;
            AppleKeyboardUIMode = 3;
            AppleICUForce24HourTime = true;
            AppleMeasurementUnits = "Centimeters";
            AppleMetricUnits = 1;
            AppleTemperatureUnit = "Celsius";
            InitialKeyRepeat = 15;
            KeyRepeat = 2;
            NSAutomaticCapitalizationEnabled = false;
            NSAutomaticDashSubstitutionEnabled = false;
            NSAutomaticPeriodSubstitutionEnabled = false;
            NSAutomaticQuoteSubstitutionEnabled = false;
            NSAutomaticSpellingCorrectionEnabled = false;
            NSAutomaticInlinePredictionEnabled = false;
            NSNavPanelExpandedStateForSaveMode = true;
            NSNavPanelExpandedStateForSaveMode2 = true;
            _HIHideMenuBar = true;
          };
          dock = {
            autohide = true;
            autohide-delay = 0.1;
            autohide-time-modifier = 0.4;
            orientation = "bottom";
            tilesize = 48;
            magnification = false;
            show-recents = false;
            mru-spaces = false;
            minimize-to-application = true;
            scroll-to-open = false;
            # Disable all hot corners.
            wvous-bl-corner = 1;
            wvous-br-corner = 1;
            wvous-tl-corner = 1;
            wvous-tr-corner = 1;
          };
          finder = {
            AppleShowAllFiles = true;
            AppleShowAllExtensions = true;
            ShowPathbar = true;
            ShowStatusBar = true;
            FXEnableExtensionChangeWarning = false;
            QuitMenuItem = true;
            _FXShowPosixPathInTitle = true;
            _FXSortFoldersFirst = true;
            FXPreferredViewStyle = "clmv";
            FXDefaultSearchScope = "SCcf";
            # No desktop icons, no internal drives.
            CreateDesktop = false;
            ShowHardDrivesOnDesktop = false;
            ShowExternalHardDrivesOnDesktop = true;
            ShowRemovableMediaOnDesktop = true;
            ShowMountedServersOnDesktop = true;
          };
          trackpad = {
            Clicking = true;
            TrackpadRightClick = true;
            TrackpadThreeFingerDrag = true;
          };
          menuExtraClock = {
            Show24Hour = true;
            ShowSeconds = true;
            ShowDate = 1;
            ShowAMPM = false;
          };
          controlcenter = {
            BatteryShowPercentage = true;
            Bluetooth = false;
            Sound = false;
            Display = false;
            AirDrop = false;
            FocusModes = false;
          };
          loginwindow = {
            GuestEnabled = false;
            DisableConsoleAccess = true;
          };
          screensaver = {
            askForPassword = true;
            askForPasswordDelay = 0;
          };
          screencapture = {
            type = "png";
            disable-shadow = true;
            show-thumbnail = true;
          };
          spaces.spans-displays = false;
          WindowManager = {
            EnableStandardClickToShowDesktop = false;
            StandardHideDesktopIcons = true;
            HideDesktop = false;
            StageManagerHideWidgets = false;
            StandardHideWidgets = false;
          };
          CustomUserPreferences = {
            "com.apple.desktopservices" = {
              # Avoid creating .DS_Store files on network or USB volumes.
              DSDontWriteNetworkStores = true;
              DSDontWriteUSBStores = true;
            };
            # Prevent Photos from opening automatically when devices are plugged in.
            "com.apple.ImageCapture".disableHotPlug = true;
            "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
          };
        };
      };
    };
}
