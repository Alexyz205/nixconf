_: {
  flake.modules.nixos.users =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.users = {
        enable = lib.mkEnableOption "User account + sudo";
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
      config = lib.mkIf config.modules.users.enable {
        users.users.${config.modules.users.userName} = {
          isNormalUser = true;
          extraGroups = config.modules.users.extraGroups;
          openssh.authorizedKeys.keys = config.modules.users.authorizedKeys;
        };
        security.sudo.wheelNeedsPassword = true;
      };
    };
}
