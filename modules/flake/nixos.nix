{
  config,
  inputs,
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
    let
      sshClient = config.flake.modules.homeManager.ssh;
      # Flake-level overlays (e.g. the fetchgit CA wrapper). The inner NixOS
      # module shadows `config`, so bind the flake config first.
      flakeOverlays = config.flake.modules.overlays;
    in
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      system.stateVersion = stateVersion;
      networking.hostName = hostName;
      nixpkgs.overlays = flakeOverlays;
      time.timeZone = "Europe/Paris";
      i18n.defaultLocale = "en_US.UTF-8";
      hardware.enableRedistributableFirmware = true;
      home-manager = {
        useGlobalPkgs = true;
        extraSpecialArgs = {
          inherit (inputs) lazyvim;
        };
        # Base SSH client config for every home-manager NixOS host.
        sharedModules = [ sshClient ];
        users.${config.modules.users.userName} = {
          home.stateVersion = stateVersion;
          nix.package = lib.mkForce pkgs.nix;
          modules.ssh.enable = true;
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
        bitwarden
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
      server =
        config.flake.nixosFeatures.base
        ++ (with features; [
          boot
          disko
          sops
          nextcloud
          podman
          containers
        ]);
      # Interactive desktop host on top of the server stack.
      desktop =
        config.flake.nixosFeatures.server
        ++ (with features; [
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
    inherit mkHostCommon;
  };
}
