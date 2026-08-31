{
  inputs,
  config,
  lib,
  ...
}:
let
  # Terminal-only tooling: the default for every host. Nothing GUI, hardware,
  # secret, or platform-specific lives here — those are opt-in extras.
  baseModules = with config.flake.modules.homeManager; [
    packages
    nix
    shell
    git
    bat
    eza
    zoxide
    starship
    tmux
    yazi
    lazygit
    lazyvim
    btop
    tv
    devenv
    opencode
  ];
  # Opt-in extras, each gated by its own `enable` option. Every extra follows
  # the same shape: the feature module + the flag that switches it on.
  extras = with config.flake.modules.homeManager; {
    sops = [
      inputs.sops-nix.homeManagerModules.sops
      sops
      { modules.sops.enable = true; }
    ];
    yubikey = [
      yubikey
      { modules.yubikey.enable = true; }
    ];
    ghostty = [
      ghostty
      { modules.ghostty.enable = true; }
    ];
    containers = [
      containers
      { modules.containers.enable = true; }
    ];
    gitlab = [
      gitlab
      { modules.gitlab.enable = true; }
    ];
  };
  # Extras for interactive desktop hosts (macos, linux, RNSL).
  desktopExtras = extras.sops ++ extras.yubikey ++ extras.ghostty ++ extras.containers;

  # Required for standalone home-manager on non-NixOS Linux: wires nix.sh into
  # the shell config so $HOME/.nix-profile/bin lands on PATH in managed shells.
  genericLinux = {
    targets.genericLinux.enable = true;
  };

  mkHome =
    {
      system,
      username,
      homeDirectory,
      modules ? baseModules,
      extra ? [ ],
    }:
    let
      baseModule =
        {
          pkgs,
          ...
        }:
        {
          home = {
            inherit username homeDirectory;
            stateVersion = "26.05";
          };
          # Replaces the old `.#tools` profile: every standalone home-manager
          # config ships the terminal tool stack (shell + basic + security
          # + devTools) plus tv.
          modules.packages = {
            basic = true;
            security = true;
            devTools = true;
          };
          modules.tv.enable = true;
          home.packages = [ pkgs.nixfmt ];
          gtk.gtk4.theme = null;
        };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        lazyvim = inputs.lazyvim;
      };
      modules = [ baseModule ] ++ modules ++ extra;
    };
in
{
  flake.homeConfigurations = {
    "alexis@macos" = mkHome {
      system = "aarch64-darwin";
      username = "alexis";
      homeDirectory = "/Users/alexis";
      extra = desktopExtras;
    };
    "alexis@linux" = mkHome {
      system = "x86_64-linux";
      username = "alexis";
      homeDirectory = "/home/alexis";
      extra = desktopExtras ++ [ genericLinux ];
    };
    "alexis.pigeon@RNSL-APIGEON5" = mkHome {
      system = "x86_64-linux";
      username = "alexis.pigeon";
      homeDirectory = "/home/alexis.pigeon";
      extra = desktopExtras ++ extras.gitlab;
    };
    # Headless Ubuntu server: terminal-only, no YubiKey / sops / GUI.
    "alexis@server" = mkHome {
      system = "x86_64-linux";
      username = "alexis";
      homeDirectory = "/home/alexis";
      extra = [ genericLinux ];
    };
    # Root-based container (devpod / docker, single-user nix): terminal-only.
    "root@container" = mkHome {
      system = "x86_64-linux";
      username = "root";
      homeDirectory = "/root";
      extra = [ genericLinux ];
    };
  };
}
