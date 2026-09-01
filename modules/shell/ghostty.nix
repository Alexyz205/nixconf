_:
let
  ghosttyCfg = { pkgs }: {
    enable = true;
    settings = {
      command = "${pkgs.tmux}/bin/tmux new-session -A -s dev";
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
        "0=#45475a"
        "1=#f38ba8"
        "2=#a6e3a1"
        "3=#f9e2af"
        "4=#89b4fa"
        "5=#f5c2e7"
        "6=#94e2d5"
        "7=#a6adc8"
        "8=#585b70"
        "9=#f38ba8"
        "10=#a6e3a1"
        "11=#f9e2af"
        "12=#89b4fa"
        "13=#f5c2e7"
        "14=#94e2d5"
        "15=#bac2de"
      ];
      background = "1e1e2e";
      foreground = "cdd6f4";
      cursor-color = "f5e0dc";
      cursor-text = "1e1e2e";
      selection-background = "353749";
      selection-foreground = "cdd6f4";
    };
  };
in
{
  flake.modules.nixos.ghostty =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.ghostty.enable = lib.mkEnableOption "Ghostty terminal";
      config = lib.mkIf config.modules.ghostty.enable {
        home-manager.users.${config.modules.users.userName}.programs.ghostty = ghosttyCfg { inherit pkgs; };
      };
    };

  flake.modules.homeManager.ghostty =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options.modules.ghostty.enable = lib.mkEnableOption "Ghostty terminal";
      config = lib.mkIf config.modules.ghostty.enable {
        home.file = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          ".config/ghostty/config".text = ''
            command = ${pkgs.tmux}/bin/tmux new-session -A -s dev
            font-family = JetBrains Mono
            font-size = 14
            mouse-hide-while-typing = true
            clipboard-paste-protection = false
            copy-on-select = true
            fullscreen = true

            background = 1e1e2e
            foreground = cdd6f4
            cursor-color = f5e0dc
            cursor-text = 1e1e2e
            selection-background = 353749
            selection-foreground = cdd6f4
            palette = 0=#45475a
            palette = 1=#f38ba8
            palette = 2=#a6e3a1
            palette = 3=#f9e2af
            palette = 4=#89b4fa
            palette = 5=#f5c2e7
            palette = 6=#94e2d5
            palette = 7=#a6adc8
            palette = 8=#585b70
            palette = 9=#f38ba8
            palette = 10=#a6e3a1
            palette = 11=#f9e2af
            palette = 12=#89b4fa
            palette = 13=#f5c2e7
            palette = 14=#94e2d5
            palette = 15=#bac2de
          '';
        };
        programs.ghostty = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) (ghosttyCfg {
          inherit pkgs;
        });
      };
    };
}
