{
  # Ganymède is a Dofus guide overlay (Tauri): a small always-on-top panel in
  # front of the game for step-by-step guides. It is not in nixpkgs, so the
  # upstream AppImage release is wrapped. The AppImage bundles WebKitGTK 4.1,
  # GTK and gdk-pixbuf, so the stock appimageTools sandbox is enough.
  #
  # The licence is contribution-only (view + PRs, no redistribution), hence
  # unfree; the derivation only fetches the GitHub release asset.
  nixconf.modules.nixos.ganymede =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      ganymede = pkgs.appimageTools.wrapType2 (finalAttrs: {
        pname = "ganymede";
        version = "1.21.0";

        src = pkgs.fetchurl {
          name = "Ganymede_amd64.AppImage";
          url = "https://github.com/GanymedeTeam/ganymede-app/releases/download/${finalAttrs.version}/Ganymede_amd64.AppImage";
          hash = "sha256-q1iaPVLBkdqXl5hExML98gX8gGwdlA7HadlrCb5U7yE=";
        };

        extraInstallCommands = ''
          install -m 444 -D ${finalAttrs.contents}/Ganymede.desktop $out/share/applications/ganymede.desktop
          # Exec must name the wrapper appimageTools creates ($out/bin/ganymede);
          # upstream ships Categories= empty, which hides it from the Game menu.
          sed -i 's|^Exec=.*|Exec=ganymede %U|' $out/share/applications/ganymede.desktop
          sed -i 's|^Categories=.*|Categories=Game;Utility;|' $out/share/applications/ganymede.desktop
          install -m 444 -D ${finalAttrs.contents}/usr/share/icons/hicolor/256x256@2/apps/ganymede.png \
            $out/share/icons/hicolor/256x256/apps/ganymede.png
        '';

        meta = {
          description = "Dofus guide overlay (community app)";
          homepage = "https://ganymede-app.com";
          license = lib.licenses.unfree;
          mainProgram = "ganymede";
          platforms = [ "x86_64-linux" ];
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        };
      });
    in
    {
      options.modules.ganymede.enable = lib.mkEnableOption "Ganymède (Dofus guide overlay)";
      config = lib.mkIf config.modules.ganymede.enable {
        environment.systemPackages = [ ganymede ];
      };
    };
}
