{
  lib,
  ...
}: let
  themeSrc = toString ./config/bat/themes;
  progCfg = {
    enable = true;
    config.theme = "Catppuccin Mocha";
    themes."Catppuccin Mocha".src = "${themeSrc}/Catppuccin Mocha.tmTheme";
  };
in {
  flake.modules.nixos.bat = { config, lib, pkgs, ... }: {
    options.modules.bat.enable = lib.mkEnableOption "Bat";
    config = lib.mkIf config.modules.bat.enable {
      environment.systemPackages = [ pkgs.bat ];
      home-manager.users."alexis.pigeon".programs.bat = progCfg;
    };
  };

  flake.modules.homeManager.bat = { ... }: {
    programs.bat = progCfg;
  };
}
