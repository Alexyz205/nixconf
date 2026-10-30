{
  nixconf.modules.nixos.prism =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.prism = {
        enable = lib.mkEnableOption "Prism Launcher (Minecraft)";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.prismlauncher.override {
            # Prism runs the game inside an FHS wrapper, so tools it shells out
            # to (Prism's "Feral GameMode" toggle, MangoHud overlay, gamescope
            # wrapper) only work when they are on that wrapper's PATH.
            additionalPrograms = with pkgs; [
              gamemode
              gamescope
              mangohud
            ];
          };
          description = ''
            Prism Launcher package used on this host, exposed so other modules
            launch the same build.
          '';
        };
        java = lib.mkOption {
          type = lib.types.package;
          default = pkgs.jdk25;
          description = ''
            JDK installed system-wide and referenced by instances as
            /run/current-system/sw/bin/java. A stable path is required: Prism
            stores the resolved /nix/store/... binary, which stops existing
            after the store path is garbage collected.
          '';
        };
      };
      config = lib.mkIf config.modules.prism.enable {
        environment.systemPackages = [
          config.modules.prism.package
          config.modules.prism.java
        ];
        # Daemons the launch wrappers talk to. steam sets the same values, so
        # both modules stay in sync without conflicting.
        programs.gamemode.enable = true;
        programs.gamescope.enable = true;
      };
    };
}
