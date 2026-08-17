{
  config,
  inputs,
  ...
}: let
  hmModules = with config.flake.modules.homeManager; [
    packages
    nix
    shell
    git
    secrets
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
  ];
in {
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      {nixpkgs.hostPlatform = "aarch64-darwin";}
      inputs.home-manager.darwinModules.home-manager
      ({pkgs, lib, ...}: let
        opencode-bin = pkgs.stdenv.mkDerivation {
          pname = "opencode";
          version = "1.18.17";
          src = pkgs.fetchzip {
            url = "https://github.com/anomalyco/opencode/releases/download/v1.18.17/opencode-darwin-arm64.zip";
            hash = "sha256-MiXUTAfmdmwGxd7ND+0A+f9XTFFMB8V+w1cO3/vcjEs=";
          };
          installPhase = ''
            mkdir -p $out/bin
            cp -r * $out/bin/
          '';
        };
      in {
        system.stateVersion = 5;
        system.primaryUser = "alexis";
        networking.hostName = "macbook";

        environment.systemPath = lib.mkBefore [
          "/opt/homebrew/bin"
          "/opt/homebrew/sbin"
        ];

        nix.settings = {
          experimental-features = ["nix-command" "flakes"];
          substituters = ["https://cache.nixos.org"];
          max-jobs = "auto";
          cores = 0;
          connect-timeout = 5;
          keep-going = true;
          fallback = true;
          warn-dirty = false;
        };

        environment.systemPackages = [opencode-bin];

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
          masApps = {};
        };

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {lazyvim = inputs.lazyvim;};
          users.alexis = {
            imports = hmModules ++ [inputs.sops-nix.homeManagerModules.sops];
            home = {
              username = "alexis";
              homeDirectory = lib.mkForce "/Users/alexis";
              stateVersion = "24.11";
            };
            nix.package = lib.mkForce pkgs.nix;
            modules = {
              packages = {
                basic = true;
                devTools = true;
              };
            };
          };
        };
      })
    ];
  };
}
