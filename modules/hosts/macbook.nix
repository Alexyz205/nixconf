{
  config,
  inputs,
  ...
}:
let
  hmModules = with config.nixconf.modules.homeManager; [
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
    btop
  ];
in
{
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      { nixpkgs.hostPlatform = "aarch64-darwin"; }
      inputs.home-manager.darwinModules.home-manager
      (config.nixconf.mkDarwinCommon {
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
            shell.hmProfile = "alexis@macos";
          };
        };
      })
    ]
    ++ config.nixconf.darwinFeatures.base
    ++ [
      {
        modules = {
          darwin.system.enable = true;
          darwin.nix.enable = true;
          darwin.defaults.enable = true;
          darwin.security.enable = true;
          darwin.homebrew.enable = true;
          darwin.fonts.enable = true;
        };
      }
    ];
  };
}
