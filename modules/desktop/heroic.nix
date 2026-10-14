{
  nixconf.modules.nixos.heroic =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.heroic = {
        enable = lib.mkEnableOption "Heroic Games Launcher";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.heroic.override {
            # gamescope/gamemode/mangohud aren't in Heroic's default FHS wrapper;
            # pull them in so Heroic can use them as optional runtime tools.
            extraPkgs =
              pkgs': with pkgs'; [
                gamescope
                gamemode
                mangohud
              ];
          };
          description = ''
            Heroic package used on this host. Exposed so other modules (e.g.
            moonshine) launch the same build with the game tools on its PATH.
          '';
        };
      };
      config = lib.mkIf config.modules.heroic.enable {
        # DXVK/VKD3D (Proton/Wine) need 32-bit Vulkan/GL drivers. Steam's module
        # pulls this in too, but Heroic should own its requirement explicitly.
        hardware.graphics.enable32Bit = true;
        environment.systemPackages = [ config.modules.heroic.package ];
        # nixpkgs' steam module mkDefault's these to false; a plain assignment
        # here overrides that. Heroic and steam both set them to true (equal
        # values merge cleanly), so either launcher gets the daemons.
        programs.gamescope.enable = true;
        programs.gamemode.enable = true;
      };
    };
}
