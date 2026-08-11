let
  progCfg = { enable = true; icons = "auto"; git = true; };
in {
  lib,
  ...
}: {
  flake.modules.nixos.eza = { config, lib, pkgs, ... }: {
    options.modules.eza.enable = lib.mkEnableOption "Eza";
    config = lib.mkIf config.modules.eza.enable {
      environment.systemPackages = [ pkgs.eza ];
      home-manager.users."alexis.pigeon".programs.eza = progCfg;
    };
  };

  flake.modules.homeManager.eza = { ... }: {
    programs.eza = progCfg;
  };
}
