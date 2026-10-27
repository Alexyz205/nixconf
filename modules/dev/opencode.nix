_:
let
  opencodeHome =
    { pkgs }:
    {
      home.packages = [ pkgs.opencode ];
      home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    };
in
{
  nixconf.modules.nixos.opencode =
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
        home-manager.users.${config.modules.users.userName} = opencodeHome { inherit pkgs; };
      };
    };

  nixconf.modules.homeManager.opencode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.opencode.enable = lib.mkEnableOption "OpenCode CLI";
      config = lib.mkIf config.modules.opencode.enable (opencodeHome {
        inherit pkgs;
      });
    };
}
