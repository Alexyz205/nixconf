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
        home-manager.users.${config.modules.users.userName}.home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD =
          "true";
      };
    };

  flake.modules.homeManager.opencode =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.opencode ];
      home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    };
}
