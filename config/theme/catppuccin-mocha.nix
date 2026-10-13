# Catppuccin Mocha palette, single source of truth for the modules that theme
# themselves (niri, noctalia, ghostty, yazi, starship, lazygit, hyprlock, the
# greeter). Mirrors pkgs.base16-schemes' catppuccin-mocha and stylix's
# base16Scheme so the values stay in sync.
#
# `palette.<name>` returns the color WITH the leading '#' (use in themes/KDL/
# JSON). `palette.raw.<name>` returns it WITHOUT '#' for consumers that want a
# bare hex (ghostty background/foreground, hyprlock rgb(...)).
let
  colors = {
    rosewater = "#f5e0dc";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    maroon = "#eba0ac";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";
    text = "#cdd6f4";
    subtext1 = "#bac2de";
    subtext0 = "#a6adc8";
    overlay2 = "#9399b2";
    overlay1 = "#7f849c";
    overlay0 = "#6c7086";
    surface2 = "#585b70";
    surface1 = "#45475a";
    surface0 = "#313244";
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
  };
in
colors
// {
  raw = builtins.mapAttrs (_: c: builtins.substring 1 (builtins.stringLength c) c) colors;
}
