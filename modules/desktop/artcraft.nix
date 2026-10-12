{
  lib,
  self,
  ...
}:
let
  runtimeLibs =
    pkgs: with pkgs; [
      vulkan-loader
      libglvnd
      wayland
      libxkbcommon
      dbus
      libx11
      libxi
      libxcursor
      libxrandr
      libxext
      libxrender
      libxfixes
      libxcb
    ];

  apps = {
    photocraft = {
      version = "0.7.0";
      hash = "sha256-ZB+DElL9MbQ+4aEuVy10QuVlLC5b9iPeCFdBw3DwyR0=";
      label = "PhotoCraft image editor";
      description = "Image editor, a clean-room Photoshop reimplementation";
    };
    lightcraft = {
      version = "0.6.0";
      hash = "sha256-1zjxazpxex5mcWmBqk+NvWjKpb+dBNF1gBoiePGPafE=";
      label = "LightCraft photo library and raw developer";
      description = "Photo library and raw developer, a clean-room Lightroom reimplementation";
    };
    pdfcraft = {
      version = "0.6.0";
      hash = "sha256-mhNuceN7RZ7VdG2+GaNkzoTPXZlcb2yYr2FH2Bg5ClM=";
      label = "PDFCraft PDF workbench";
      description = "PDF workbench, a clean-room Acrobat reimplementation";
    };
    filmcraft = {
      version = "0.6.0";
      hash = "sha256-s9cG1Zlpnq12tGop1Wlyh7n3WgvJ60D3cz23ZX2uggQ=";
      label = "FilmCraft video editor";
      description = "Video editor with color and sound, a clean-room Premiere Pro reimplementation";
      extraBuildInputs = pkgs: [ pkgs.alsa-lib ];
      extraRuntimeLibs =
        pkgs: with pkgs; [
          alsa-lib
          libva
        ];
    };
  };

  mkArtCraft =
    pkgs: name:
    let
      app = apps.${name};
      extra = app.extraRuntimeLibs or (_: [ ]);
      extraBuild = app.extraBuildInputs or (_: [ ]);
    in
    pkgs.stdenv.mkDerivation {
      pname = name;
      inherit (app) version;
      src = pkgs.fetchurl {
        url = "https://github.com/storytold/${name}/releases/download/v${app.version}/${name}-${app.version}-linux-x86_64.tar.gz";
        inherit (app) hash;
      };
      sourceRoot = "${name}-${app.version}-linux-x86_64";
      nativeBuildInputs = [
        pkgs.autoPatchelfHook
        pkgs.makeWrapper
      ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ] ++ extraBuild pkgs;
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r bin share $out/
        for exe in $out/bin/*; do
          wrapProgram $exe \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (runtimeLibs pkgs ++ extra pkgs)}
        done
        runHook postInstall
      '';
      meta = {
        inherit (app) description;
        homepage = "https://github.com/storytold/${name}";
        license = with lib.licenses; [
          mit
          asl20
        ];
        platforms = [ "x86_64-linux" ];
        mainProgram = name;
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };

  mkFeature =
    target: name:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.${name}.enable = lib.mkEnableOption apps.${name}.label;
      config = lib.mkIf config.modules.${name}.enable (
        lib.setAttrByPath (lib.splitString "." target) [ self.packages.${pkgs.system}.${name} ]
      );
    };
in
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    lib.optionalAttrs (system == "x86_64-linux") {
      packages = builtins.mapAttrs (name: _: mkArtCraft pkgs name) apps;
    };

  flake.modules = {
    nixos = builtins.mapAttrs (name: _: mkFeature "environment.systemPackages" name) apps;
    homeManager = builtins.mapAttrs (name: _: mkFeature "home.packages" name) apps;
  };
}
