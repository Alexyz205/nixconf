{
  lib,
  self,
  ...
}:
let
  version = "0.6.0";
in
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    if system == "x86_64-linux" then
      let
        src = pkgs.fetchurl {
          # Stable asset-ID URL on Cap's CDN (GitHub releases carry no binaries).
          url = "https://cdn.crabnebula.app/asset/01M2JEFVZ6RWH8VMMGT2EH37G1";
          sha256 = "afbee5275b862cf71761ba7318d0bfcea1772f2e599c75411927b8bcbd3bb6e1";
        };
        # Extracted AppImage: provides the .DirIcon we ship for launchers. The
        # same extraction wrapType2 does internally, so the derivation is shared.
        contents = pkgs.appimageTools.extract {
          pname = "cap";
          inherit version src;
        };
      in
      {
        packages.cap = pkgs.appimageTools.wrapType2 {
          pname = "cap";
          inherit version src;
          extraPkgs = pkgs: [
            pkgs.cacert
            pkgs.libayatana-appindicator
            pkgs.alsa-lib
            pkgs.alsa-plugins
            pkgs.pipewire
          ];
          # wrapType2 only produces the FHS wrapper binary; add a .desktop entry
          # (and the AppImage's icon set, including the tray icons) so cap shows
          # up in app launchers (Noctalia, GNOME) and its tray icon renders.
          extraInstallCommands = ''
            mkdir -p $out/share/applications $out/share/icons
            cp -r ${contents}/usr/share/icons/. $out/share/icons/
            cat > $out/share/applications/cap.desktop <<'EOF'
            [Desktop Entry]
            Type=Application
            Name=Cap
            Comment=Beautiful, shareable screen recordings
            Exec=cap
            Icon=Cap
            StartupWMClass=Cap
            Terminal=false
            Categories=AudioVideo;Recorder;Utility;
            Keywords=screen;recording;screenshot;capture;
            MimeType=application/x-cap-project;x-scheme-handler/cap-desktop;
            EOF
          '';
          meta = {
            description = "Beautiful, shareable screen recordings (screen recorder + screenshots)";
            homepage = "https://cap.so";
            license = lib.licenses.agpl3Only;
            platforms = [ "x86_64-linux" ];
            mainProgram = "cap";
            sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
          };
        };
      }
    else
      { };

  nixconf.modules.nixos.cap =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.cap.enable = lib.mkEnableOption "Cap screen recorder";
      config = lib.mkIf config.modules.cap.enable {
        environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.cap ];
      };
    };

  nixconf.modules.homeManager.cap =
    {
      config,
      lib,
      self,
      pkgs,
      ...
    }:
    {
      options.modules.cap.enable = lib.mkEnableOption "Cap screen recorder";
      config = lib.mkIf config.modules.cap.enable {
        home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.cap ];
      };
    };
}
