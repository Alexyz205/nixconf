{
  config,
  inputs,
  ...
}:
let
  hmModules = with config.flake.modules.homeManager; [
    packages
    nix
    shell
    git
    bitwarden
    ssh
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
    opencode
    devenv
    tv
  ];
in
{
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      { nixpkgs.hostPlatform = "aarch64-darwin"; }
      { nixpkgs.overlays = config.flake.modules.overlays; }
      inputs.home-manager.darwinModules.home-manager
      (
        { pkgs, lib, ... }:
        {
          system.stateVersion = 7;
          system.primaryUser = "alexis";
          networking.hostName = "macbook";
          networking.knownNetworkServices = [
            "Wi-Fi"
            "Ethernet"
          ];
          networking.dns = [ "192.168.1.253" ];

          environment.systemPath = lib.mkBefore [
            "/opt/homebrew/bin"
            "/opt/homebrew/sbin"
          ];

          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            substituters = [ "https://cache.nixos.org" ];
            max-jobs = "auto";
            cores = 0;
            connect-timeout = 5;
            keep-going = true;
            fallback = true;
            warn-dirty = false;
          };

          homebrew = {
            enable = true;
            onActivation = {
              autoUpdate = true;
              cleanup = "uninstall";
              upgrade = true;
            };
            brews = [
              "openssh"
              "libfido2"
            ];
            casks = [
              "ghostty"
            ];
            masApps = { };
          };

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit (inputs) lazyvim;
            };
            users.alexis = {
              imports = hmModules ++ [ inputs.sops-nix.homeManagerModules.sops ];
              home = {
                username = "alexis";
                homeDirectory = lib.mkForce "/Users/alexis";
                stateVersion = "26.05";
              };
              nix.package = lib.mkForce pkgs.nix;
              modules = {
                packages = {
                  basic = true;
                  devTools = true;
                };
                bitwarden = {
                  enable = true;
                  desktop = true;
                };
                tv.enable = true;
              };
            };
          };
        }
      )
    ];
  };
}
