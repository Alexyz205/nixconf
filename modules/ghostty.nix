{ lib, ... }:
let
  ghosttyCfg = {
    enable = true;
    settings = {
      theme = "catppuccin-mocha";
      "font-family" = "JetBrains Mono";
      "mouse-hide-while-typing" = true;
      "font-size" = 14;
      "clipboard-paste-protection" = false;
      "copy-on-select" = true;
      fullscreen = true;
    };
    themes."catppuccin-mocha" = {
      palette = [
        "0=#45475a" "1=#f38ba8" "2=#a6e3a1" "3=#f9e2af"
        "4=#89b4fa" "5=#f5c2e7" "6=#94e2d5" "7=#a6adc8"
        "8=#585b70" "9=#f38ba8" "10=#a6e3a1" "11=#f9e2af"
        "12=#89b4fa" "13=#f5c2e7" "14=#94e2d5" "15=#bac2de"
      ];
      background = "1e1e2e";
      foreground = "cdd6f4";
      cursor-color = "f5e0dc";
      cursor-text = "1e1e2e";
      selection-background = "353749";
      selection-foreground = "cdd6f4";
    };
  };
in {
  flake.modules.nixos.ghostty = { config, lib, pkgs, ... }: {
    options.modules.ghostty.enable = lib.mkEnableOption "Ghostty terminal";
    config = lib.mkIf config.modules.ghostty.enable {
      home-manager.users."alexis.pigeon".programs.ghostty = ghosttyCfg;
    };
  };

  flake.modules.homeManager.ghostty = { ... }: {
    programs.ghostty = ghosttyCfg;
  };
}
