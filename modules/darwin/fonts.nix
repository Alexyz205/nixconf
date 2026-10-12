_: {
  flake.modules.darwin.fonts =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.darwin.fonts.enable = lib.mkEnableOption "macOS fonts";
      config = lib.mkIf config.modules.darwin.fonts.enable {
        fonts.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          nerd-fonts.symbols-only
        ];
      };
    };
}
