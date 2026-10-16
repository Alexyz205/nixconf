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
      home.packages = [ inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default ];
      home.file.".config/Claude/claude_desktop_config.json" = claudeConfigFile;
      xdg.mimeApps.defaultApplications."x-scheme-handler/claude" = [ "com.anthropic.Claude.desktop" ];
    };
in
{
  flake-file.inputs.claude-desktop = {
    url = "github:GoByeBye/claude-desktop-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixconf.modules.nixos.claude =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.claude.enable = lib.mkEnableOption "Claude desktop app";
      config = lib.mkIf config.modules.claude.enable {
        environment.systemPackages = [
          inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
        home-manager.users.${config.modules.users.userName} = homeConfig { inherit pkgs; };
      };
    };

  nixconf.modules.homeManager.claude =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.claude.enable = lib.mkEnableOption "Claude desktop app";
      config = lib.mkIf config.modules.claude.enable (homeConfig {
        inherit pkgs;
      });
    };
}
