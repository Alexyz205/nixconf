{ lib, ... }:
let
  blenderVersionDir = pkgs: lib.versions.majorMinor pkgs.blender.version;

  mkExtension =
    {
      id,
      version,
      url,
      hash,
    }:
    pkgs:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "blender-extension-${id}";
      inherit version;
      src = pkgs.fetchurl { inherit url hash; };
      nativeBuildInputs = [ pkgs.python3 ];
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        unpack=$(mktemp -d)
        ${pkgs.python3}/bin/python3 - "$src" "$unpack" <<'PY'
        import os
        import sys
        import zipfile

        src, dest = sys.argv[1], sys.argv[2]
        with zipfile.ZipFile(src) as archive:
            for info in archive.infolist():
                name = info.filename.replace(chr(92), "/")
                if name.endswith("/"):
                    continue
                target = os.path.join(dest, name)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with archive.open(info) as source, open(target, "wb") as output:
                    output.write(source.read())
        PY
        root=$(dirname "$(find "$unpack" -name blender_manifest.toml -print -quit)")
        mkdir -p "$out/system/${id}"
        cp -a "$root"/. "$out/system/${id}/"
        runHook postInstall
      '';
      meta = {
        description = "Blender extension ${id}";
        license = lib.licenses.gpl3Plus;
      };
    };

  extensions = [
    (mkExtension {
      id = "print3d_toolbox";
      version = "1.5.0";
      url = "https://extensions.blender.org/download/sha256:3e3121a8052d52ce1fe8fd13bc6431679018f0cf1cb51ac0224fc47073a8e12a/add-on-print3d-toolbox-v1.5.0.zip";
      hash = "sha256-PjEhqAUtUs4f6P0TvGQxZ5AY8M8ctRrAIk/EcHOo4So=";
    })
    (mkExtension {
      id = "measureit";
      version = "1.8.4";
      url = "https://extensions.blender.org/download/sha256:85b1836d97e5c2f0311afdf45cf9fd3cefa71bade074963864ce40ee15c26042/add-on-measureit-v1.8.4.zip";
      hash = "sha256-hbGDbZflwvAxGv30XPn9PO+nG63gdJY4ZM5A7hXCYEI=";
    })
    (mkExtension {
      id = "yl_meshcheckhud";
      version = "1.2.3";
      url = "https://extensions.blender.org/download/sha256:549e94b28f37fd7b7503e8a08cfabbf52c60c9ca8824cb68fbd4b593b0ce3363/add-on-yl-meshcheckhud-v1.2.3.zip";
      hash = "sha256-VJ6Uso83/Xt1A+igjPq79SxgycqIJMto+9S1k7DOM2M=";
    })
    (mkExtension {
      id = "printing_helper";
      version = "0.1.2";
      url = "https://extensions.blender.org/download/sha256:3c3a5ea8c40c1cf91c3102b5c7d690ef8ae38a6a562daf4f2200574c2faabeae/add-on-printing-helper-v0.1.2.zip";
      hash = "sha256-PDpeqMQMHPkcMQK1x9aQ74rjimpWLa9PIgBXTC+qvq4=";
    })
    (mkExtension {
      id = "print_prep";
      version = "1.0.3";
      url = "https://extensions.blender.org/download/sha256:49463f52f956ed99c107a6bccaa081c4cb4672a4d101fcb7781a44657c6de04e/add-on-print-prep-v1.0.3.zip";
      hash = "sha256-SUY/UvlW7ZnBB6a8yqCBxMtGcqTRAfy3eBpEZXxt4E4=";
    })
    (mkExtension {
      id = "easy_print";
      version = "0.1.2";
      url = "https://extensions.blender.org/download/sha256:0a5a5d59aaf6657dddde3d1921a5e71a4bc9245973fc60511f12a4b2b9b54b06/add-on-easy-print-v0.1.2.zip";
      hash = "sha256-ClpdWar2ZX3d3j0ZIaXnGkvJJFlz/GBRHxKksrm1SwY=";
    })
  ];

  catppuccinTheme =
    pkgs:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Zentropivity/catppuccin-blender/main/Catppuccin_Mocha.xml";
      hash = "sha256-s5Pct7PbacyWgUVJp0hXWr9xb7ENuPkuLfKc1SlA9wE=";
    };

  blenderMcpAddon =
    pkgs:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "blender-mcp-addon";
      version = "1.8";
      src = pkgs.fetchFromGitHub {
        owner = "ahujasid";
        repo = "mcp-for-blender";
        rev = "febcd90ece59c3416d7c55fd3723cea46bcaa59d";
        hash = "sha256-8D3DWeGAcffqwi0VUIpkoTLMzhG39CWj9OeaeRlT9OA=";
      };
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/addons"
        cp addon.py "$out/addons/blender_mcp.py"
        runHook postInstall
      '';
      meta = {
        description = "MCP bridge add-on for Blender";
        homepage = "https://github.com/ahujasid/mcp-for-blender";
        license = lib.licenses.mit;
      };
    };

  mkBlender =
    pkgs: cudaSupport:
    let
      base =
        if cudaSupport && pkgs.stdenv.hostPlatform.isLinux then
          pkgs.blender.override { inherit cudaSupport; }
        else
          pkgs.blender;
      extensionsRepo = pkgs.buildEnv {
        name = "blender-extensions";
        paths = map (extension: extension pkgs) extensions;
        pathsToLink = [ "/system" ];
      };
      scriptsRepo = pkgs.buildEnv {
        name = "blender-scripts";
        paths = [ (blenderMcpAddon pkgs) ];
        pathsToLink = [ "/addons" ];
      };
    in
    pkgs.symlinkJoin {
      name = "blender-${base.version}";
      paths = [ base ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/blender" \
          --set BLENDER_SYSTEM_EXTENSIONS "${extensionsRepo}" \
          --set BLENDER_SYSTEM_SCRIPTS "${scriptsRepo}"
      '';
      inherit (base) meta;
    };

  homeCfg =
    {
      pkgs,
      lib,
      cudaSupport,
    }:
    {
      home.packages = [ (mkBlender pkgs cudaSupport) ];
      home.file.".config/blender/${blenderVersionDir pkgs}/scripts/presets/interface_theme/Catppuccin_Mocha.xml".source =
        catppuccinTheme pkgs;
      home.activation.blenderPrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "$HOME/.config/blender/${blenderVersionDir pkgs}/config/userpref.blend" ]; then
          $DRY_RUN_CMD ${mkBlender pkgs cudaSupport}/bin/blender --background --factory-startup \
            --python ${../../config/blender/seed.py} >/dev/null 2>&1 || true
        fi
      '';
      xdg.mimeApps.defaultApplications."application/x-blender" = "blender.desktop";
    };
in
{
  nixconf.modules.nixos.blender =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.blender = {
        enable = lib.mkEnableOption "Blender 5 with CUDA/OptiX and 3D-print addons";
        cudaSupport = lib.mkEnableOption "Blender Cycles CUDA/OptiX support";
      };
      config = lib.mkIf (config.modules.blender.enable && pkgs.stdenv.hostPlatform.isLinux) {
        home-manager.users.${config.modules.users.userName} =
          { pkgs, lib, ... }:
          homeCfg {
            inherit pkgs lib;
            inherit (config.modules.blender) cudaSupport;
          };
      };
    };

  nixconf.modules.homeManager.blender =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.blender = {
        enable = lib.mkEnableOption "Blender 5 with CUDA/OptiX and 3D-print addons";
        cudaSupport = lib.mkEnableOption "Blender Cycles CUDA/OptiX support";
      };
      config = lib.mkIf (config.modules.blender.enable && pkgs.stdenv.hostPlatform.isLinux) (homeCfg {
        inherit pkgs lib;
        inherit (config.modules.blender) cudaSupport;
      });
    };
}
