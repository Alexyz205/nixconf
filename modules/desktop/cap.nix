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
