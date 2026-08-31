{
  lib,
  ...
}:
{
  flake.modules.nixos.hiddenApps =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
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
        enable = lib.mkEnableOption "Hide desktop entries of terminal-only apps from the app launcher";
        apps = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "yazi"
            "btop"
            "nvim"
            "xterm"
          ];
          description = "Desktop entry names to mark NoDisplay=true so launchers hide them.";
        };
      };

      config = lib.mkIf config.modules.hiddenApps.enable {
        home-manager.users.${config.modules.users.userName}.home.file =
          files config.modules.hiddenApps.apps;
      };
    };
}
