{ ... }: {
  flake.modules.nixos.opencode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.opencode.enable = lib.mkEnableOption "OpenCode CLI";
      config = lib.mkIf config.modules.opencode.enable {
        environment.systemPackages = [ pkgs.opencode ];
      };
    };

  flake.modules.homeManager.opencode =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.opencode ];
    };
}
