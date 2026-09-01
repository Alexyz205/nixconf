{
  lib,
  ...
}:
let
  zshHook = ''eval "$(devenv hook zsh)"'';
  homeCfg =
    {
      pkgs,
      lib,
    }:
    {
      home.packages = [ pkgs.devenv ];
      programs.zsh.initContent = lib.mkOrder 500 zshHook;
    };
in
{
  flake.modules.nixos.devenv =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.devenv.enable = lib.mkEnableOption "devenv native auto-activation";
      config = lib.mkIf config.modules.devenv.enable {
        environment.systemPackages = [ pkgs.devenv ];
        home-manager.users.${config.modules.users.userName} = homeCfg {
          inherit pkgs lib;
        };
      };
    };

  flake.modules.homeManager.devenv =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.devenv.enable = lib.mkEnableOption "devenv native auto-activation";
      config = lib.mkIf config.modules.devenv.enable (homeCfg {
        inherit pkgs lib;
      });
    };
}
