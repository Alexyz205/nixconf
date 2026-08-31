{
  lib,
  ...
}:
let
  zshHook = ''eval "$(devenv hook zsh)"'';
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
        home-manager.users.${config.modules.users.userName} = {
          programs.zsh.initContent = lib.mkOrder 500 zshHook;
        };
      };
    };

  flake.modules.homeManager.devenv =
    {
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.devenv ];
      programs.zsh.initContent = lib.mkOrder 500 zshHook;
    };
}
