{
  config,
  inputs,
  lib,
  ...
}:
let
  features = config.flake.modules.nixos;

  # Shared NixOS host boilerplate: system defaults + home-manager wiring that
  # every disko-managed host repeats. Keeps hosts to their deltas only.
  mkHostCommon =
    {
      hostName,
      stateVersion,
    }:
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      system.stateVersion = stateVersion;
      networking.hostName = hostName;
      time.timeZone = "Europe/Paris";
      i18n.defaultLocale = "en_US.UTF-8";
      hardware.enableRedistributableFirmware = true;
      home-manager = {
        useGlobalPkgs = true;
        extraSpecialArgs = {
          lazyvim = inputs.lazyvim;
        };
        users.${config.modules.users.userName} = {
          home.stateVersion = stateVersion;
          nix.package = lib.mkForce pkgs.nix;
        };
      };
    };
in
{
  config.flake = {
    nixosFeatures = {
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
    mkHostCommon = mkHostCommon;
  };
}