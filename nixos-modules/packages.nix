# Packages module: Nix-managed system packages, grouped so hosts pick
# what they need. Per the video pattern, each group is a toggle.
#
# Strategy: user-facing CLI tools (neovim, tmux, starship, gh, opencode,
# fabric, gcc, kubectl, helm, ...) are installed per-user by MISE from
# config/mise/config.toml, NOT here. This module only carries system-level
# tooling that mise does not manage well: containers and security/secrets.
#
# Enable with `modules.packages.enable = true` and flip the groups you want.
{ config, lib, pkgs, ... }:

{
  options.modules.packages = {
    enable = lib.mkEnableOption "Nix-managed system packages";

    basic = lib.mkEnableOption "basic system utilities";
    containers = lib.mkEnableOption "container orchestration tooling";
    security = lib.mkEnableOption "security / secrets tooling";
  };

  config = lib.mkIf config.modules.packages.enable {
    environment.systemPackages = with pkgs;
      (lib.optionals config.modules.packages.basic [
        curl
        wget
        openssl
      ])
      ++ (lib.optionals config.modules.packages.containers [
        devpod
        docker-compose
        podman-compose
      ])
      ++ (lib.optionals config.modules.packages.security [
        pass
        age
        sops
        gnupg
      ]);
  };
}
