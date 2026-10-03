{
  flake.modules.nixos.heroic =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.heroic.enable = lib.mkEnableOption "Heroic Games Launcher";
      config = lib.mkIf config.modules.heroic.enable {
        # DXVK/VKD3D (Proton/Wine) need 32-bit Vulkan/GL drivers. Steam's module
        # pulls this in too, but Heroic should own its requirement explicitly.
        hardware.graphics.enable32Bit = true;
        environment.systemPackages = [
          (pkgs.heroic.override {
            # gamescope/gamemode/mangohud aren't in Heroic's default FHS wrapper;
            # pull them in so Heroic can use them as optional runtime tools.
            extraPkgs =
              pkgs': with pkgs'; [
                gamescope
                gamemode
                mangohud
              ];
          })
        ];
        programs.gamescope.enable = true;
        programs.gamemode.enable = true;
      };
    };
}
