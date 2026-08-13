{lib, ...}: let
  themeSrc = toString ./config/bat/themes;
  batCfg = {
    enable = true;
    config.theme = "Catppuccin Mocha";
    themes."Catppuccin Mocha".src = "${themeSrc}/Catppuccin Mocha.tmTheme";
  };
in {
  flake.modules.nixos.bat = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.bat.enable = lib.mkEnableOption "Bat";
    config = lib.mkIf config.modules.bat.enable {
      environment.systemPackages = [pkgs.bat];
      home-manager.users."alexis" = {
        programs.bat = batCfg;
        stylix.targets.bat.enable = false;
      };
    };
  };

  flake.modules.homeManager.bat = {...}: {
    programs.bat = batCfg;
  };
}
