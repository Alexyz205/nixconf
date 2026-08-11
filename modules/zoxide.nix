let
  progCfg = { enable = true; enableBashIntegration = true; enableZshIntegration = true; };
in {
  lib,
  ...
}: {
  flake.modules.nixos.zoxide = { config, lib, pkgs, ... }: {
    options.modules.zoxide.enable = lib.mkEnableOption "Zoxide";
    config = lib.mkIf config.modules.zoxide.enable {
      environment.systemPackages = [ pkgs.zoxide ];
      home-manager.users."alexis.pigeon".programs.zoxide = progCfg;
    };
  };

  flake.modules.homeManager.zoxide = { ... }: {
    programs.zoxide = progCfg;
  };
}
