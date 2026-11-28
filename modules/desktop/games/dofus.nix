{ inputs, ... }:
{
  # Dofus 3 is distributed as an Ankama Launcher AppImage that downloads the
  # Unity client. The launcher is unfree and its download URL carries no
  # version, so the source is pinned by hash (refreshed with
  # `nix store prefetch-file`).
  flake-file.inputs.x11-ewmh-shim = {
    url = "github:yannhodiesne/x11-ewmh-shim";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixconf.modules.nixos.dofus =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Same recipe as nixpkgs' pkgs/by-name/an/ankama-launcher, but sourced
      # from Ankama's CDN instead of a web.archive.org snapshot: the snapshot
      # nixpkgs pins is both stale and slow (hundreds of KB/s), while the CDN
      # serves the current launcher at full speed. nixpkgs' version check is
      # kept so a launcher upgrade fails loudly instead of silently shipping a
      # mismatched version string.
      ankama-launcher = pkgs.appimageTools.wrapType2 (finalAttrs: {
        pname = "ankama-launcher";
        version = "3.15.20";

        src = pkgs.fetchurl {
          name = "ankama-launcher.AppImage";
          url = "https://launcher.cdn.ankama.com/installers/production/Ankama%20Launcher-Setup-x86_64.AppImage";
          hash = "sha256-ZnJXodXjO1MFnvcfJh0Dczupf4OK9JIqpPuq2ALfdMI=";
        };

        # The launcher can start Windows-only Ankama titles through Wine.
        extraPkgs = p: [ p.wine ];

        extraInstallCommands = ''
          desktop_file="${finalAttrs.contents}/zaap.desktop"

          nix_version="${finalAttrs.version}"
          archive_version=$(grep -oP '(?<=X-AppImage-Version=).*' $desktop_file)

          if [[ "$archive_version" != "$nix_version"* ]]; then
            echo "ERROR - Version mismatch:"
            echo -e "\t- Expected (version): $nix_version"
            echo -e "\t- Version found in 'zaap.desktop': $archive_version"
            exit 1
          fi

          install -m 444 -D "$desktop_file" $out/share/applications/ankama-launcher.desktop
          sed -i 's/.*Exec.*/Exec=ankama-launcher/' $out/share/applications/ankama-launcher.desktop
          install -m 444 -D ${finalAttrs.contents}/zaap.png $out/share/icons/hicolor/256x256/apps/zaap.png
        '';

        meta = {
          description = "Ankama Launcher (Dofus 3, Wakfu portal)";
          homepage = "https://www.ankama.com/en/launcher";
          license = lib.licenses.unfree;
          mainProgram = "ankama-launcher";
          platforms = [ "x86_64-linux" ];
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        };
      });

      # Everything the launcher exports is inherited by the game it spawns, so
      # these are set here instead of in zaap-start.sh (which the launcher
      # rewrites on every update):
      #
      # - __GLX_VENDOR_LIBRARY_NAME=nvidia: the Unity client does not pick the
      #   NVIDIA driver on its own and falls back to software rendering.
      # - SDL_VIDEODRIVER=x11: Unity 6's Wayland backend is broken under
      #   xwayland-satellite; the game must be a GLX/X11 client. This is also
      #   the backend x11-ewmh-shim fixes (the app's own desktop entry drops
      #   this, Ankama documents it in their Linux troubleshooting).
      # - --no-sandbox: the AppImage ships an Electron build; its chrome-sandbox
      #   is not setuid in the Nix store, and Ankama's own desktop entry passes
      #   --no-sandbox too (appimageTools' sed replaces Exec and loses it).
      launcher = pkgs.symlinkJoin {
        name = "ankama-launcher-nvidia";
        paths = [ ankama-launcher ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/ankama-launcher \
            --set __GLX_VENDOR_LIBRARY_NAME nvidia \
            --set SDL_VIDEODRIVER x11 \
            --add-flags "--no-sandbox"
        '';
      };
    in
    {
      options.modules.dofus.enable = lib.mkEnableOption "Dofus 3 (Ankama Launcher)";
      config = lib.mkIf config.modules.dofus.enable {
        environment.systemPackages = [ launcher ];

        # Dofus 3 (Unity 6) aborts at startup under niri + xwayland-satellite:
        # libScreenManagerNativeProxy fails to register its RandR callbacks
        # (BadValue) and crashes reading an empty display list. The shim publishes
        # the EWMH root properties xwayland-satellite omits, which is what the
        # game's screen manager expects.
        home-manager.sharedModules = [
          inputs.x11-ewmh-shim.homeManagerModules.default
          { x11-ewmh-shim.enable = true; }
        ];
      };
    };
}
