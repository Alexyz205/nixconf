# Users module: user account(s) + sudo policy.
# Enable with `modules.users.enable = true`.
{ config, lib, pkgs, ... }:

{
  options.modules.users = {
    enable = lib.mkEnableOption "user account management";
    userName = lib.mkOption {
      type = lib.types.str;
      default = "alexis";
    };
    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "wheel" "networkmanager" "podman" ];
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
      # Account is LOCKED at install time (no password set).
      # After first boot: `sudo passwd alexis`
      initialHashedPassword = "!";
      openssh.authorizedKeys.keys = config.modules.users.authorizedKeys;
      # The dotfiles installer sets up zsh configs; make it the login shell.
      shell = pkgs.zsh;
    };

    security.sudo.wheelNeedsPassword = true;
  };
}
