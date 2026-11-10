# Upstream portable Blender, used by modules/desktop/blender.nix instead of
# nixpkgs' source build.
#
# Why: `pkgs.blender.override { cudaSupport = true; }` compiles Cycles CUDA and
# OptiX device binaries for every architecture the nixpkgs CUDA package set
# knows about (ten on nixpkgs 26.11, sm_75 through sm_121), plus CUDA-enabled
# OpenSubdiv and OpenImageDenoise. None of that is in a binary cache, so every
# nixpkgs bump rebuilds it locally. The official Linux build ships those kernels
# precompiled, so this derivation is a fetch + patchelf.
#
# Trade-offs (deliberate): bundled libraries (Python, ffmpeg, OpenSSL, ...) only
# receive security updates with a Blender release, not with nixpkgs. The NVIDIA
# driver libraries are loaded from the host at runtime and are therefore in
# autoPatchelfIgnoreMissingDeps. Bump `version` and `hash` together.
#
# Update the hash with:
#   nix store prefetch-file --json \
#     https://download.blender.org/release/Blender<major.minor>/blender-<version>-linux-x64.tar.xz
pkgs:
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "blender";
  version = "5.2.4";
  src = pkgs.fetchurl {
    url = "https://download.blender.org/release/Blender${pkgs.lib.versions.majorMinor finalAttrs.version}/blender-${finalAttrs.version}-linux-x64.tar.xz";
    hash = "sha256-L9FMUJh0Jol7pgI37plu3ytBUfSxpypGDKIL5YwdLYY=";
  };

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = with pkgs; [
    alsa-lib
    libglvnd
    libpulseaudio
    libxcb
    libdrm
    libjack2
    libxkbcommon
    libdecor
    level-zero
    ncurses
    pipewire
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXt
    xorg.libICE
    xorg.libSM
    xorg.libXxf86vm
  ];

  # ROCm, Steam and legacy GLES loader names are only needed by optional
  # bundled backends (HIP OpenImageDenoise, Steam Input, SDL GLES). Cycles
  # CUDA/OptiX never asks for them.
  autoPatchelfIgnoreMissingDeps = [
    "libamdhip64.so.7"
    "libGLES_CM.so.1"
    "libsteam_api.so"
    "libcuda.so.1"
    "libnvidia-encode.so.1"
    "libnvcuvid.so.1"
    "libnvoptix.so.1"
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a . "$out/"

    mkdir -p "$out/bin" "$out/share/applications" "$out/share/icons/hicolor/scalable/apps"
    mv "$out/blender.desktop" "$out/share/applications/blender.desktop"
    mv "$out/blender.svg" "$out/share/icons/hicolor/scalable/apps/blender.svg"
    rm -f "$out/blender-symbolic.svg"

    # A tiny shim so makeWrapper (called by the module to add the extensions
    # and MCP paths) wraps a regular file instead of the 174 MB binary.
    printf '#!/bin/sh\nexec "%s/blender" "$@"\n' "$out" >"$out/bin/blender"
    chmod +x "$out/bin/blender"
    runHook postInstall
  '';

  meta = {
    description = "Blender 3D creation suite (upstream portable build with prebuilt Cycles CUDA/OptiX kernels)";
    homepage = "https://www.blender.org";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "blender";
  };
})
