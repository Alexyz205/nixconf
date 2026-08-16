{
  lib,
  inputs,
  ...
}: let
  claudeConfig = {
    mcpServers = {};
  };
in {
  flake.modules.nixos.claude = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.claude.enable = lib.mkEnableOption "Claude desktop app";
    config = lib.mkIf config.modules.claude.enable {
      environment.systemPackages = [inputs.claude-desktop.packages.${pkgs.system}.default];
      home-manager.users.${config.modules.users.userName} = {
        home.file.".config/Claude/claude_desktop_config.json".text = builtins.toJSON claudeConfig;
      };
    };
  };

  flake.modules.homeManager.claude = {
    config,
    lib,
    pkgs,
    ...
  }: {
    nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-desktop";
    home.packages = [inputs.claude-desktop.packages.${pkgs.system}.default];
    home.file.".config/Claude/claude_desktop_config.json".text = builtins.toJSON claudeConfig;
  };
}
