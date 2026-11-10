{
  config,
  inputs,
  ...
}:
let
  lib = inputs.nixpkgs.lib;
  features = config.nixconf.modules.nixos;

  # Terminal-only tooling: the default for every NixOS host with home-manager.
  baseNames = [
    "nix"
    "users"
    "security"
    "ssh"
    "shell"
    "git"
    "bitwarden"
    "packages"
    "starship"
    "tmux"
    "bat"
    "eza"
    "diskusage"
    "zoxide"
    "lazygit"
    "lazyvim"
    "yazi"
    "tv"
    "opencode"
  ];
  # Full headless server: base + storage, secrets and the container runtime.
  serverNames = baseNames ++ [
    "boot"
    "disko"
    "sops"
    "nextcloud"
    "podman"
    "containers"
    "backup"
    "monitoring"
    "secureBoot"
    "wakeOnLan"
    "impermanence"
  ];
  # Interactive desktop host on top of the server stack.
  desktopNames = serverNames ++ [
    "network"
    "yubikey"
    "devenv"
    "btop"
    "ghostty"
    "niri"
    "noctalia"
    "hiddenApps"
    "lock"
    "chromium"
    "claude"
    "discord"
    "steam"
    "heroic"
    "prism"
    "controller"
    "thunderbird"
    "youtubeMusic"
    "cap"
    "gitlab"
    "blender"
    "freecad"
    "imv"
    "photocraft"
    "lightcraft"
    "pdfcraft"
    "filmcraft"
    "wordcraft"
    "gridcraft"
    "cadcraft"
    "deckcraft"
    "soundcraft"
  ];

  # Features that are imported by a tier but stay off until a host opts in
  # (they change boot security or need an external backup destination).
  optInNames = [
    "backup"
    "secureBoot"
    "impermanence"
  ];

  # A tier is a single NixOS module that both imports the feature modules and
  # switches them on with `mkDefault`. Hosts then declare only their deltas and
  # can still disable any feature with a plain `modules.<name>.enable = false`.
  enableTier = names: {
    imports = map (name: features.${name}) names;
    config.modules = lib.genAttrs (builtins.filter (name: !builtins.elem name optInNames) names) (_: {
      enable = lib.mkDefault true;
    });
  };

  # Shared NixOS host boilerplate: system defaults + home-manager wiring that
  # every disko-managed host repeats. Keeps hosts to their deltas only.
  mkHostCommon =
    {
      hostName,
      stateVersion,
    }:
    let
      sshClient = config.nixconf.modules.homeManager.ssh;
      # Flake-level overlays (e.g. the fetchgit CA wrapper). The inner NixOS
      # module shadows `config`, so bind the flake config first.
      flakeOverlays = config.nixconf.modules.overlays;
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
      # Latest stable Nix for the daemon + CLI on every host.
      nix.package = pkgs.nixVersions.latest;
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
          nix.package = lib.mkForce pkgs.nixVersions.latest;
          modules.ssh.enable = true;
        };
      };
    };
in
{
  config.nixconf = {
    nixosFeatures = {
      base = [ (enableTier baseNames) ];
      server = [ (enableTier serverNames) ];
      desktop = [ (enableTier desktopNames) ];
    };
    inherit mkHostCommon;
  };
}
