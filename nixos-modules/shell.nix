# Shell module: zsh + git + the minimal tools needed to bootstrap the
# per-user toolchain (mise). Enable with `modules.shell.enable = true`.
#
# Strategy: user-facing CLI tools (neovim, tmux, starship, eza, gh, ...)
# are installed per-user by MISE from config/mise/config.toml, so versions
# can switch per project. This module only installs the system-level basics
# needed BEFORE mise is set up: the shell, git, and the mise binary itself.
# Optional heavier groups (dev, k8s, containers, security) live in
# packages.nix and are enabled per host.
{ config, lib, pkgs, ... }:

{
  options.modules.shell = {
    enable = lib.mkEnableOption "zsh + git + bootstrap essentials";
  };

  config = lib.mkIf config.modules.shell.enable {
    programs.zsh.enable = true;
    programs.git.enable = true;

    environment.systemPackages = with pkgs; [
      # The dotfiles installer (clone dotfiles -> ./install) uses these.
      git
      curl
      wget
      openssl
      mise # language runtimes + all per-user tools (node, go, tmux, ...)
    ];
  };
}
