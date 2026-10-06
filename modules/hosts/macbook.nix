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
    nextcloudRclone
    btop
  ];
in
{
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      { nixpkgs.hostPlatform = "aarch64-darwin"; }
      inputs.home-manager.darwinModules.home-manager
      (config.flake.mkDarwinCommon {
        hostName = "macbook";
        systemStateVersion = 7;
        homeStateVersion = "26.05";
        userName = "alexis";
        homeDirectory = "/Users/alexis";
        inherit hmModules;
        hmSettings = {
          modules = {
            packages = {
              basic = true;
              security = true;
              devTools = true;
            };
            sops.enable = true;
            bitwarden = {
              enable = true;
              desktop = true;
            };
            nextcloudRclone.enable = true;
            tv.enable = true;
            nix.enable = true;
            shell.enable = true;
            git.enable = true;
            ssh.enable = true;
            bat.enable = true;
            eza.enable = true;
            zoxide.enable = true;
            starship.enable = true;
            tmux.enable = true;
            yazi.enable = true;
            lazygit.enable = true;
            ghostty.enable = true;
            lazyvim.enable = true;
            yubikey.enable = true;
            opencode.enable = true;
            devenv.enable = true;
            btop.enable = true;
          };
        };
      })
    ]
    ++ config.flake.darwinFeatures.base
    ++ [
      {
        modules = {
          system.enable = true;
          nix.enable = true;
          defaults.enable = true;
          security.enable = true;
          homebrew.enable = true;
          fonts.enable = true;
        };
      }
    ];
  };
}
