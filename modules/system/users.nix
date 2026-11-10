_: {
  nixconf.modules.nixos.users =
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
        hashedPasswordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            File holding the crypt(3) hash of the user's password, read on every
            activation. Needed on hosts with ephemeral root: /etc/shadow is
            recreated at boot, so an imperative `passwd` would not survive.
            Keep the file on the persistent volume (or a sops secret).
          '';
        };
      };
      config = lib.mkIf config.modules.users.enable {
        users.users.${config.modules.users.userName} = {
          isNormalUser = true;
          extraGroups = config.modules.users.extraGroups;
          openssh.authorizedKeys.keys = config.modules.users.authorizedKeys;
          inherit (config.modules.users) hashedPasswordFile;
        };
        security.sudo.wheelNeedsPassword = true;
      };
    };
}
