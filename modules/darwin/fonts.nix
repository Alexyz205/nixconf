_: {
  flake.modules.darwin.fonts =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.fonts.enable = lib.mkEnableOption "macOS fonts";
      config = lib.mkIf config.modules.fonts.enable {
        fonts.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          nerd-fonts.symbols-only
        ];
      };
    };
}
