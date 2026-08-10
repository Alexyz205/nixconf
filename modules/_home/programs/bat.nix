{
  config,
  lib,
  pkgs,
  ...
}:
let
  themeSrc = "${toString ./../../config/bat/themes}/Catppuccin Mocha.tmTheme";
in
{
  programs.bat = {
    enable = true;

    config = {
      theme = "Catppuccin Mocha";
    };

    themes."Catppuccin Mocha".src = themeSrc;
  };
}
