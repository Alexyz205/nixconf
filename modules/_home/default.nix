{
  config,
  pkgs,
  lib,
  lazyvim,
  ...
}:
{
  imports = [
    lazyvim.homeManagerModules.default
    ./env.nix
    ./packages.nix
    ./files.nix
    ./programs/starship.nix
    ./programs/git.nix
    ./programs/zsh.nix
    ./programs/bash.nix
    ./programs/tmux.nix
    ./programs/bat.nix
    ./programs/eza.nix
    ./programs/lazygit.nix
    ./programs/lazyvim.nix
    ./programs/yazi.nix
    ./programs/ghostty.nix
    ./programs/zoxide.nix
  ];

  home = {
    username = "alexis.pigeon";
    homeDirectory = "/home/alexis.pigeon";
    stateVersion = "24.11";
    sessionPath = [
      "${config.home.homeDirectory}/bin"
      "${config.home.homeDirectory}/.local/bin"
    ];
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [ "https://cache.nixos.org" ];
      max-jobs = 8;
      cores = 0;
      connect-timeout = 0;
      keep-going = true;
      fallback = true;
      warn-dirty = false;
    };
  };

  programs.home-manager.enable = true;
}
