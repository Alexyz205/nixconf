_:
let
  palette = import ../../config/theme/catppuccin-mocha.nix;
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
        "0=${palette.surface1}"
        "1=${palette.red}"
        "2=${palette.green}"
        "3=${palette.yellow}"
        "4=${palette.blue}"
        "5=${palette.pink}"
        "6=${palette.teal}"
        "7=${palette.subtext0}"
        "8=${palette.surface2}"
        "9=${palette.red}"
        "10=${palette.green}"
        "11=${palette.yellow}"
        "12=${palette.blue}"
        "13=${palette.pink}"
        "14=${palette.teal}"
        "15=${palette.subtext1}"
      ];
      background = palette.raw.base;
      foreground = palette.raw.text;
      cursor-color = palette.raw.rosewater;
      cursor-text = palette.raw.base;
      selection-background = "353749";
      selection-foreground = palette.raw.text;
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

            background = ${palette.raw.base}
            foreground = ${palette.raw.text}
            cursor-color = ${palette.raw.rosewater}
            cursor-text = ${palette.raw.base}
            selection-background = 353749
            selection-foreground = ${palette.raw.text}
            palette = 0=${palette.surface1}
            palette = 1=${palette.red}
            palette = 2=${palette.green}
            palette = 3=${palette.yellow}
            palette = 4=${palette.blue}
            palette = 5=${palette.pink}
            palette = 6=${palette.teal}
            palette = 7=${palette.subtext0}
            palette = 8=${palette.surface2}
            palette = 9=${palette.red}
            palette = 10=${palette.green}
            palette = 11=${palette.yellow}
            palette = 12=${palette.blue}
            palette = 13=${palette.pink}
            palette = 14=${palette.teal}
            palette = 15=${palette.subtext1}
          '';
        };
        programs.ghostty = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) (ghosttyCfg {
          inherit pkgs;
        });
      };
    };
}
