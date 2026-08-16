{
  lib,
  ...
}: {
  flake.modules.nixos.steam = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.steam.enable = lib.mkEnableOption "Steam";
    config = lib.mkIf config.modules.steam.enable {
      programs.steam.enable = true;
      # Steam's CEF (web view) renders black / no window under niri's XWayland
      # when GPU-accelerated. -system-composer (niri-recommended) renders the UI
      # via the compositor instead. See niri "Application-Specific Issues: Steam".
      programs.steam.package = pkgs.steam.override {
        extraArgs = "-system-composer";
      };
    };
  };
}