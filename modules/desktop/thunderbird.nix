{
  lib,
  ...
}:
let
  # Options shared by the NixOS and home-manager sides.
  thunderbirdOptions = {
    enable = lib.mkEnableOption "Thunderbird mail client (Infomaniak)";
    email = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching ".*@.*");
      default = null;
      description = "Infomaniak address to preconfigure in Thunderbird (IMAP/SMTP on mail.infomaniak.com). The password is entered once inside Thunderbird.";
    };
    realName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Display name used when sending mail. Defaults to the email address.";
    };
  };

  # Shared home-manager config: Thunderbird profile + preconfigured Infomaniak
  # account (when an email is set). Values are passed in explicitly so the NixOS
  # side doesn't depend on home-manager option space.
  mkHmCfg =
    {
      pkgs,
      email,
      realName,
    }:
    let
      themeId = "{47f5c9df-1d03-5424-ae9e-0613b69a9d2f}";
      theme = pkgs.runCommand "catppuccin-mocha-mauve.thunderbird.theme" { } ''
        mkdir -p "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
        cp "${
          pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/catppuccin/thunderbird/0289f3bd9566f9666682f66a3355155c0d0563fc/themes/mocha/mocha-mauve.xpi";
            sha256 = "02a72b10ecc121d6dac717ebca08784aeef6e2b7f177a956e42fa1604ee49f40";
          }
        }" "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/${themeId}.xpi"
      '';
      infomaniak = lib.optionalAttrs (email != null) {
        accounts.email.accounts.infomaniak = {
          primary = true;
          address = email;
          userName = email;
          realName = if realName != null then realName else email;
          imap = {
            host = "mail.infomaniak.com";
            port = 993;
            tls.enable = true;
          };
          smtp = {
            host = "mail.infomaniak.com";
            port = 587;
            tls = {
              enable = true;
              useStartTls = true;
            };
          };
          thunderbird.enable = true;
        };
      };
    in
    {
      programs.thunderbird = {
        enable = true;
        profiles.main = {
          isDefault = true;
          extensions = [ theme ];
          settings = {
            "datareporting.healthreport.uploadEnabled" = false;
            "datareporting.policy.dataSubmissionEnabled" = false;
            # Install the Catppuccin theme without it being auto-disabled, and
            # make it the active theme (installing a static theme XPI does not
            # select it on its own).
            "extensions.autoDisableScopes" = 0;
            "extensions.activeThemeID" = themeId;
          };
        };
      };
      programs.zsh.shellAliases = {
        tb = "thunderbird";
      };
    }
    // infomaniak;
in
{
  flake.modules.nixos.thunderbird =
    {
      config,
      pkgs,
      ...
    }:
    {
      options.modules.thunderbird = thunderbirdOptions;
      config = lib.mkIf config.modules.thunderbird.enable {
        home-manager.users.${config.modules.users.userName} = mkHmCfg {
          inherit pkgs;
          email = config.modules.thunderbird.email;
          realName = config.modules.thunderbird.realName;
        };
      };
    };

  flake.modules.homeManager.thunderbird =
    {
      config,
      pkgs,
      ...
    }:
    {
      options.modules.thunderbird = thunderbirdOptions;
      config = lib.mkIf config.modules.thunderbird.enable (mkHmCfg {
        inherit pkgs;
        email = config.modules.thunderbird.email;
        realName = config.modules.thunderbird.realName;
      });
    };
}
