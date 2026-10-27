_:
let
  baseConfig = builtins.fromJSON (builtins.readFile ../../config/opencode/opencode.json);

  opencodeHome =
    {
      pkgs,
      lib,
      mcp,
    }:
    let
      mcpServers =
        lib.optionalAttrs mcp.blender.enable {
          blender = {
            type = "local";
            command = [
              "${pkgs.uv}/bin/uvx"
              "--from"
              "mcp-for-blender==2.0.0"
              "mcp-for-blender"
            ];
            disabled = false;
          };
        }
        // lib.optionalAttrs mcp.freecad.enable {
          freecad = {
            type = "local";
            command = [
              "${pkgs.uv}/bin/uvx"
              "--from"
              "freecad-mcp==0.1.28"
              "freecad-mcp"
            ];
            disabled = false;
          };
        };

      config = baseConfig // {
        mcp = {
          servers = (baseConfig.mcp.servers or { }) // mcpServers;
        };
      };
    in
    {
      home.packages = [
        pkgs.opencode
      ]
      ++ lib.optional (mcp.blender.enable || mcp.freecad.enable) pkgs.uv;
      home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
      home.file.".config/opencode/opencode.json".text = builtins.toJSON config;
    };

  mcpOptions = lib: {
    blender.enable = lib.mkEnableOption "Blender MCP server for OpenCode";
    freecad.enable = lib.mkEnableOption "FreeCAD MCP server for OpenCode";
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
      options.modules.opencode = {
        enable = lib.mkEnableOption "OpenCode CLI";
        mcp = mcpOptions lib;
      };
      config = lib.mkIf config.modules.opencode.enable {
        environment.systemPackages = [ pkgs.opencode ];
        home-manager.users.${config.modules.users.userName} =
          { pkgs, lib, ... }:
          opencodeHome {
            inherit pkgs lib;
            mcp = config.modules.opencode.mcp;
          };
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
      options.modules.opencode = {
        enable = lib.mkEnableOption "OpenCode CLI";
        mcp = mcpOptions lib;
      };
      config = lib.mkIf config.modules.opencode.enable (opencodeHome {
        inherit pkgs lib;
        mcp = config.modules.opencode.mcp;
      });
    };
}
