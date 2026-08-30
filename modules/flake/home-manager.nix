{
  inputs,
  config,
  lib,
  ...
}: let
  fullModules = with config.flake.modules.homeManager; [
    packages
    nix
    shell
    git
    gitlab
    containers
    sops
    bat
    eza
    zoxide
    starship
    tmux
    yazi
    lazygit
    ghostty
    lazyvim
    yubikey
    devenv
    opencode
    btop
    tv
  ];
  # Containers can't reach the YubiKey, so sops (secret decryption), the
  # hardware ssh key (yubikey), and the RNSL-only gitlab module are excluded.
  containerModules = with config.flake.modules.homeManager; [
    packages
    nix
    shell
    git
    containers
    bat
    eza
    zoxide
    starship
    tmux
    yazi
    lazygit
    lazyvim
    devenv
    opencode
    btop
    tv
  ];

  mkHome = {
    system,
    username,
    homeDirectory,
    modules,
    withSops ? true,
    extra ? {},
  }: let
    baseModule = {
      pkgs,
      ...
    }: {
      home = {
        inherit username homeDirectory;
        stateVersion = "24.11";
      };
      # Replaces the old `.#tools` profile: every standalone home-manager
      # config ships the full nixconf tool stack (shell + basic + security
      # + devTools) plus the tools that used to live in tools.nix.
      modules.packages = {
        basic = true;
        security = true;
        devTools = true;
      };
      modules.containers.enable = true;
      modules.tv.enable = true;
      home.packages = [pkgs.nixfmt-rfc-style];
      gtk.gtk4.theme = null;
    };
  in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        lazyvim = inputs.lazyvim;
      };
      modules =
        (lib.optionals withSops [inputs.sops-nix.homeManagerModules.sops])
        ++ [baseModule]
        ++ modules
        ++ [extra];
    };
in {
  flake.homeConfigurations = {
    "alexis@macos" = mkHome {
      system = "aarch64-darwin";
      username = "alexis";
      homeDirectory = "/Users/alexis";
      modules = fullModules;
    };
    "alexis@linux" = mkHome {
      system = "x86_64-linux";
      username = "alexis";
      homeDirectory = "/home/alexis";
      modules = fullModules;
    };
    "alexis.pigeon@RNSL-APIGEON5" = mkHome {
      system = "x86_64-linux";
      username = "alexis.pigeon";
      homeDirectory = "/home/alexis.pigeon";
      modules = fullModules;
      extra = {
        modules.gitlab.enable = true;
      };
    };
    "alexis@container" = mkHome {
      system = "x86_64-linux";
      username = "alexis";
      homeDirectory = "/home/alexis";
      modules = containerModules;
      withSops = false;
    };
  };
}