{
  config,
  ...
}:
let
  homeHiddenAppsModule = config.nixconf.modules.homeManager.hiddenApps;
in
{
  nixconf.modules.nixos.hiddenApps =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.hiddenApps.enable = lib.mkEnableOption "Hide terminal-only apps from the graphical app launcher";

      config = lib.mkIf config.modules.hiddenApps.enable {
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (_: {
          imports = [ homeHiddenAppsModule ];
          modules.hiddenApps.enable = true;
        });
      };
    };

  nixconf.modules.homeManager.hiddenApps =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Terminal-only tools and shell internals that should never appear in a
      # graphical launcher (Noctalia reads XDG .desktop entries).
      defaultApps = [
        "btop"
        "dev.noctalia.Noctalia"
        "nvim"
        "yazi"
      ];

      # Generate a one-file store object so home.file can copy from it.
      mkHide =
        name:
        pkgs.runCommand "hide-${name}" { } ''
          mkdir -p $out
          cat > $out/${name}.desktop <<'EOF'
          [Desktop Entry]
          Name=Hidden
          Type=Application
          NoDisplay=true
          EOF
        '';

      files =
        apps:
        builtins.listToAttrs (
          map (name: {
            name = ".local/share/applications/${name}.desktop";
            value = {
              source = "${mkHide name}/${name}.desktop";
            };
          }) apps
        );
    in
    {
      options.modules.hiddenApps = {
        enable = lib.mkEnableOption "Hide terminal-only apps from the graphical app launcher";
        apps = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = defaultApps;
          description = "Desktop entry names to mark NoDisplay=true so launchers hide them.";
        };
      };

      config = lib.mkIf config.modules.hiddenApps.enable {
        home.file = files config.modules.hiddenApps.apps;
      };
    };
}
