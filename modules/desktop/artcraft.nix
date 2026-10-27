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
      version = "0.16.0";
      hash = "sha256-fBfzYz6/favydiji0mN9kYx8KlsWO4uQNHp4rN32Ngg=";
      label = "PhotoCraft image editor";
      description = "Image editor, a clean-room Photoshop reimplementation";
    };
    lightcraft = {
      version = "0.14.0";
      hash = "sha256-uCM7k3PW6ZsRgMHDn9yxPUnEQfgAkncIMfqxlcTE/aI=";
      label = "LightCraft photo library and raw developer";
      description = "Photo library and raw developer, a clean-room Lightroom reimplementation";
    };
    pdfcraft = {
      version = "0.14.0";
      hash = "sha256-qT9RHof2MDbKX1MAsaehijzSKFIF3qsVOUyqbug8bx8=";
      label = "PDFCraft PDF workbench";
      description = "PDF workbench, a clean-room Acrobat reimplementation";
    };
    filmcraft = {
      version = "0.13.0";
      hash = "sha256-QOnWhfs+0bCiHJwCIR8ahJngmkfFUSRM5+6A8lhNOps=";
      label = "FilmCraft video editor";
      description = "Video editor with color and sound, a clean-room Premiere Pro reimplementation";
      extraBuildInputs = pkgs: [ pkgs.alsa-lib ];
      extraRuntimeLibs =
        pkgs: with pkgs; [
          alsa-lib
          libva
        ];
    };
    wordcraft = {
      version = "0.11.0";
      hash = "sha256-A0wke/basXKi7fsHZ96QZRJbhXgmxpFffvObn0OVHVo=";
      label = "WordCraft word processor";
      description = "Word processor, a clean-room Microsoft Word reimplementation";
    };
    gridcraft = {
      version = "0.12.1";
      hash = "sha256-HBdQ3W0mN2z4yK8itG3A7T2NXLsRXlVfD8fQz3qa6po=";
      label = "GridCraft spreadsheet";
      description = "Spreadsheet, a clean-room Microsoft Excel reimplementation";
    };
    cadcraft = {
      version = "0.13.0";
      hash = "sha256-04dVvrYYiXVr69k430kebuDeeMLzX9NRBaR5kJ/RypI=";
      label = "CADCraft CAD and drafting";
      description = "Computer-aided design and drafting, a clean-room AutoCAD reimplementation";
    };
    deckcraft = {
      version = "0.11.1";
      hash = "sha256-e/V6EKT892c+y2abZODlRUdXgO8+Tua/YDrrAPVE5pw=";
      label = "DeckCraft presentations";
      description = "Presentations and slide shows, a clean-room Microsoft PowerPoint reimplementation";
      extraBuildInputs = pkgs: [ pkgs.alsa-lib ];
      extraRuntimeLibs = pkgs: [ pkgs.alsa-lib ];
    };
    soundcraft = {
      version = "0.13.1";
      hash = "sha256-Ce5siEWTT+70u/TFwOLw/8o/yREm/XpqQGGx+DkHRW0=";
      label = "SoundCraft audio workstation";
      description = "Digital audio workstation, a clean-room Avid Pro Tools reimplementation";
      extraBuildInputs = pkgs: [ pkgs.alsa-lib ];
      extraRuntimeLibs = pkgs: [ pkgs.alsa-lib ];
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
        lib.setAttrByPath (lib.splitString "." target) [
          self.packages.${pkgs.stdenv.hostPlatform.system}.${name}
        ]
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

  nixconf.modules = {
    nixos = builtins.mapAttrs (name: _: mkFeature "environment.systemPackages" name) apps;
    homeManager = builtins.mapAttrs (name: _: mkFeature "home.packages" name) apps;
  };
}
