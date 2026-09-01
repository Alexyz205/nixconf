{
  inputs,
  ...
}:
let
  # Claude desktop writes this file on first run, so `force` is required for
  # home-manager to overwrite it with the managed config.
  claudeConfigFile = {
    force = true;
    text = builtins.toJSON {
      mcpServers = { };
    };
  };
  # Home-manager side shared by NixOS hosts and standalone profiles.
  homeConfig =
    { pkgs }:
    {
      home.packages = [ inputs.claude-desktop.packages.${pkgs.system}.default ];
      home.file.".config/Claude/claude_desktop_config.json" = claudeConfigFile;
    };
in
{
  flake.modules.nixos.claude =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.claude.enable = lib.mkEnableOption "Claude desktop app";
      config = lib.mkIf config.modules.claude.enable {
        environment.systemPackages = [ inputs.claude-desktop.packages.${pkgs.system}.default ];
        home-manager.users.${config.modules.users.userName} = homeConfig { inherit pkgs; };
      };
    };

  flake.modules.homeManager.claude =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.claude.enable = lib.mkEnableOption "Claude desktop app";
      config = lib.mkIf config.modules.claude.enable (
        homeConfig {
          inherit pkgs;
        }
        // {
          nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-desktop";
        }
      );
    };
}
