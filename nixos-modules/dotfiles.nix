# Dotfiles module: automatically clone the user's dotfiles repo and run its
# installer on first login. Enable with `modules.dotfiles.enable = true`.
#
# Strategy:
#   - A systemd USER unit runs once the user's session starts (at boot too if
#     linger is enabled, see README) and clones the dotfiles repo into the
#     user's home, then runs its `install` script (symlinks + mise tools).
#   - The repo is public, so the HTTPS URL works without any auth. Point
#     `modules.dotfiles.url` at an SSH URL instead once sops is set up.
#   - Skipped automatically if the target directory already exists (idempotent).
{ config, lib, pkgs, ... }:

{
  options.modules.dotfiles = {
    enable = lib.mkEnableOption "dotfiles bootstrap (clone + install on first login)";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Alexyz205/dotfiles.git";
      description = "git URL of the dotfiles repo.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "alexis";
      description = "User whose home the dotfiles are installed into.";
    };

    directory = lib.mkOption {
      type = lib.types.str;
      default = "dotfiles";
      description = "Directory name inside the user's home (e.g. 'dotfiles').";
    };
  };

  config = lib.mkIf config.modules.dotfiles.enable {
    systemd.user.services.dotfiles-bootstrap = {
      description = "Clone dotfiles and run installer";
      # Starts with the user session; with linger it also starts at boot.
      wantedBy = [ "default.target" ];
      # Wait for the network so the clone can succeed.
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = with pkgs; [ git bash coreutils gnused curl wget ];

      script = ''
        target="$HOME/${config.modules.dotfiles.directory}"
        if [ -e "$target" ]; then
          exit 0
        fi
        git clone --recursive ${config.modules.dotfiles.url} "$target"
        bash "$target/install"
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Retry until it succeeds (e.g. if the network is slow at first boot).
        Restart = "on-failure";
        RestartSec = 30;
      };
    };
  };
}
