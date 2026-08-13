{
  lib,
  ...
}: {
  flake.modules.nixos.users = {
    config,
    lib,
    ...
  }: {
    options.modules.users = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = "alexis";
      };
      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["wheel" "networkmanager" "podman"];
      };
      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      hashedPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a file containing the hashed password (e.g., from sops-nix).";
      };
    };
    config = {
      users.users.${config.modules.users.userName} =
        {
          isNormalUser = true;
          extraGroups = config.modules.users.extraGroups;
          openssh.authorizedKeys.keys = config.modules.users.authorizedKeys;
        }
        // lib.optionalAttrs (config.modules.users.hashedPasswordFile != null) {
          hashedPasswordFile = config.modules.users.hashedPasswordFile;
        };
      security.sudo.wheelNeedsPassword = true;
    };
  };
}
