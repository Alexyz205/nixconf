{
  lib,
  ...
}:
{
  flake.modules.nixos.users =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.users = {
        userName = lib.mkOption {
          type = lib.types.str;
          default = "alexis";
        };
        extraGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "wheel"
            "networkmanager"
            "podman"
          ];
        };
        authorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };
      config = {
        users.users.${config.modules.users.userName} = {
          isNormalUser = true;
          extraGroups = config.modules.users.extraGroups;
          openssh.authorizedKeys.keys = config.modules.users.authorizedKeys;
        };
        security.sudo.wheelNeedsPassword = true;
      };
    };
}
