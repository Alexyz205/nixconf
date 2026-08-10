{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
  };
}
