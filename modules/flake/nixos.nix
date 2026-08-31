{
  config,
  lib,
  ...
}:
let
  features = config.flake.modules.nixos;
in
{
  config.flake.nixosFeatures = {
    # Terminal-only tooling: the default for every NixOS host with home-manager.
    base = with features; [
      nix
      users
      security
      ssh
      shell
      git
      packages
      starship
      tmux
      bat
      eza
      zoxide
      lazygit
      lazyvim
      yazi
      tv
      opencode
    ];
    # Full headless server: base + storage, secrets and the container runtime.
    server = config.flake.nixosFeatures.base ++ (with features; [
      boot
      disko
      sops
      podman
      containers
    ]);
    # Interactive desktop host on top of the server stack.
    desktop = config.flake.nixosFeatures.server ++ (with features; [
      network
      yubikey
      devenv
      btop
      ghostty
      niri
      noctalia
      hiddenApps
      brave
      claude
      discord
      steam
      youtubeMusic
    ]);
  };
}