let
  ezaCfg = {
    enable = true;
    icons = "auto";
    git = true;
  };
  ezaAliases = {
    ls = "eza --color=auto --icons=auto";
    la = "eza -la --icons=auto";
    ll = "eza -l --git --hyperlink --icons=auto";
    lt = "eza --tree --level=2 --icons=auto";
    lta = "eza --tree --level=2 --icons=auto -a";
    ltl = "eza --tree --level=2 --icons=auto -l";
    ldir = "eza --long --icons=auto --only-dirs";
    lm = "eza --icons=auto --sort=modified";
    lz = "eza --icons=auto --sort=size";
  };
  homeCfg = {
    programs.eza = ezaCfg;
    programs.zsh.shellAliases = ezaAliases;
  };
in
{ lib, ... }: {
  flake.modules.nixos.eza =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.eza.enable = lib.mkEnableOption "Eza";
      config = lib.mkIf config.modules.eza.enable {
        environment.systemPackages = [ pkgs.eza ];
        home-manager.users.${config.modules.users.userName} = homeCfg;
      };
    };

  flake.modules.homeManager.eza =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.eza.enable = lib.mkEnableOption "Eza";
      config = lib.mkIf config.modules.eza.enable homeCfg;
    };
}
