{
  lib,
  ...
}:
{
  flake.modules.nixos.discord =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.discord.enable = lib.mkEnableOption "Discord via Vesktop (Vencord)";
      config = lib.mkIf config.modules.discord.enable {
        environment.systemPackages = [ pkgs.vesktop ];
        home-manager.users.${config.modules.users.userName} = lib.optionalAttrs (config ? stylix) {
          stylix.targets.vesktop.enable = true;
        };
      };
    };
}
