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
      ...
    }:
    let
      src = pkgs.fetchurl {
        # Stable asset-ID URL on Cap's CDN (GitHub releases carry no binaries).
        url = "https://cdn.crabnebula.app/asset/01M2JEFVZ6RWH8VMMGT2EH37G1";
        sha256 = "afbee5275b862cf71761ba7318d0bfcea1772f2e599c75411927b8bcbd3bb6e1";
      };
      appimageContents = pkgs.appimageTools.extract {
        pname = "cap";
        inherit version src;
      };
    in
    {
      # Wraps Cap's official AppImage in an FHS env. The AppImage bundles
      # webkitgtk/gtk3/gstreamer/ffmpeg itself, but Cap's finalizer strips
      # libwayland-client + libpipewire so the app can use the host's PipeWire
      # for capture — wrapType2's default multiPkgs already provides both.
      #
      # NVIDIA/Wayland quirks handled here:
      # - WebKitGTK's DMABUF renderer renders garbage frames on NVIDIA
      #   (tauri-apps/tauri#9394) — disable it.
      # - Cap's wgpu/GPUI renderer falls back to a GLES/EGL backend that can't
      #   create a context on NVIDIA with the bundled Mesa ("dri2 screen"
      #   failure), which makes the selection overlay render pink. Two-part fix:
      #     * WGPU_BACKEND=vulkan + VK_ICD_FILENAMES route wgpu's shared
      #       context to the NVIDIA Vulkan adapter (hardware, fast).
      #     * LIBGL_ALWAYS_SOFTWARE=1 gives WebKitGTK's own GL a working
      #       llvmpipe path, so the webview previews render correct pixels
      #       instead of pink garbage.
      packages.cap = pkgs.appimageTools.wrapType2 {
        pname = "cap";
        inherit version src;
        # libayatana-appindicator is required by Cap's tray icon; without it the
        # Tauri tray setup panics on startup. alsa-lib + alsa-plugins + pipewire
        # give ALSA a usable config so `default`/`pulse`/`pipewire` PCMs resolve.
        extraPkgs = pkgs: [
          pkgs.cacert
          pkgs.libayatana-appindicator
          pkgs.alsa-lib
          pkgs.alsa-plugins
          pkgs.pipewire
        ];
        profile = ''
          export WEBKIT_DISABLE_DMABUF_RENDERER=1
          export __NV_DISABLE_EXPLICIT_SYNC=1
          export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          export WGPU_BACKEND=vulkan
          export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
          export LIBGL_ALWAYS_SOFTWARE=1
        '';
        extraInstallCommands = ''
          install -Dm644 ${appimageContents}/Cap.desktop $out/share/applications/Cap.desktop
          substituteInPlace $out/share/applications/Cap.desktop --replace-fail 'Exec=Cap' 'Exec=cap'
          install -Dm644 ${appimageContents}/usr/share/icons/hicolor/128x128/apps/Cap.png \
            $out/share/icons/hicolor/128x128/apps/Cap.png
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
    };

  flake.modules.nixos.cap =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.cap.enable = lib.mkEnableOption "Cap screen recorder";
      config = lib.mkIf config.modules.cap.enable {
        environment.systemPackages = [ self.packages.${pkgs.system}.cap ];
      };
    };
}
