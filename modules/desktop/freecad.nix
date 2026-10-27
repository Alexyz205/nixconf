{ lib, ... }:
let
  catppuccinSrc =
    pkgs:
    pkgs.fetchFromGitHub {
      owner = "cnvuls";
      repo = "CatppuccinTheme";
      rev = "67157dc98fba2ec841162ece6db32cde169bacab";
      hash = "sha256-OhAZVGKSFshAZ8f/10Sb/Y5+rJecnas2szH8ujSdgOY=";
    };

  mkAddon =
    {
      name,
      owner,
      repo,
      rev,
      hash,
      subdir ? null,
    }:
    {
      inherit name;
      pkg =
        pkgs:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "freecad-addon-${name}";
          inherit rev;
          version = rev;
          src = pkgs.fetchFromGitHub {
            inherit
              owner
              repo
              rev
              hash
              ;
          };
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cp -a ${if subdir == null then "$src" else "$src/${subdir}"}/. "$out"/
            runHook postInstall
          '';
          meta = {
            description = "FreeCAD add-on ${name}";
            license = lib.licenses.lgpl2Plus;
          };
        };
    };

  addons = [
    (mkAddon {
      name = "3D_Printing_Tools";
      owner = "mark1791";
      repo = "3D_Printing_Tools";
      rev = "e7ea9cd05dc11d5503115522b87cac7704eafc0e";
      hash = "sha256-L6Jjd4jRcNN0rgHbURSgt5EqvcNs0tqRZ67Y+KfBxb0=";
    })
    (mkAddon {
      name = "MeshRemodel";
      owner = "mwganson";
      repo = "MeshRemodel";
      rev = "540cdf528aad5f09018caf30cea5e39c11765cc8";
      hash = "sha256-PZsrYluH2anJdVDWo9QlH8tA6xYWH0aUDB2z/+3s5Ik=";
    })
    (mkAddon {
      name = "Defeaturing";
      owner = "easyw";
      repo = "Defeaturing_WB";
      rev = "460cfdd02bddc622443b3dc78cc3ed2d31ccf0bd";
      hash = "sha256-28k9sO7F/5r2W0IqulfHN92WA/4ll/Dc108r0veEUJg=";
    })
    (mkAddon {
      name = "Fasteners";
      owner = "shaise";
      repo = "FreeCAD_FastenersWB";
      rev = "fddd07af422b7d3a69098b32333711c5eeae184c";
      hash = "sha256-5Thrf7AnyXZJfn2nguEmCT+Q0wXNcnKvWzOtwsnIeHI=";
    })
    (mkAddon {
      name = "SheetMetal";
      owner = "shaise";
      repo = "FreeCAD_SheetMetal";
      rev = "cbf6595b68ad015266923749c160c3555a72e1fd";
      hash = "sha256-2aL5d5ktQLL3cp2d4aIYMqspuf/NbrnmOJiXipDRR0g=";
    })
    (mkAddon {
      name = "ThreadProfile";
      owner = "mwganson";
      repo = "ThreadProfile";
      rev = "2aa2e739c0f401d3addd28fd172d9f74c304aabc";
      hash = "sha256-WCwkWaxTdjJTDE/PzBPe4j8ljSCYHgmrh7NZHEAQhYM=";
    })
    (mkAddon {
      name = "gears";
      owner = "looooo";
      repo = "freecad.gears";
      rev = "83ec154b1925347622b61812f75d2ed51e956b9f";
      hash = "sha256-BLEIdkRe/eX+ef5WrqCnFB+HxBqu/on26dyoUH0q16w=";
    })
    (mkAddon {
      name = "Curves";
      owner = "tomate44";
      repo = "CurvesWB";
      rev = "c08e21ba16b8d6c6846cee3c9a6b1ea950987f36";
      hash = "sha256-r2fULNvf+durt7+YV7CmOlln59NaT9j1sNAnTRUGwcA=";
    })
    (mkAddon {
      name = "Lattice2";
      owner = "DeepSOIC";
      repo = "Lattice2";
      rev = "9595449b80a634179ecaeae2525b91c93dc52cb1";
      hash = "sha256-FIQtlJj22Dvfn2j4sPC+huAPSCxTOmu6HsaV3rRXUMo=";
    })
    (mkAddon {
      name = "Manipulator";
      owner = "easyw";
      repo = "Manipulator";
      rev = "6d8990469d1c1c2788c873af96ebecff2377833d";
      hash = "sha256-rp+YC/3k+9hDNfvkhBZQ1oUc1EoUmrZP0ix5RVxgxZI=";
    })
    (mkAddon {
      name = "FreeCADMCP";
      owner = "neka-nat";
      repo = "freecad-mcp";
      rev = "8babe9927ce8e6e8fe7dd6ae2ffa2c93776e845a";
      hash = "sha256-dryocwUb26S1+msUTZDUYGoyizxKuAeqMiTqyD8/ybo=";
      subdir = "addon/FreeCADMCP";
    })
  ];

  mkFreecad =
    pkgs:
    pkgs.freecad.customize {
      name = "freecad";
      # FreeCAD 1.1 registers every --module-path entry as a single add-on and
      # then runs `<entry>/InitGui.py`, so each add-on has to be passed as its
      # own path — a linkFarm holding all of them is one path with no InitGui.py
      # and silently loads nothing.
      modules = map (addon: addon.pkg pkgs) addons;
      makeWrapperFlags = [
        "--set"
        "QT_QPA_PLATFORM"
        "xcb"
        # FreeCAD 1.1 looks its home up with getpwuid() and throws (then
        # segfaults on the uninitialised interpreter) when the host resolves
        # users through a service the Nix glibc can't load — e.g. SSSD/LDAP
        # accounts that aren't in /etc/passwd, as on the work stations.
        # Pointing the custom dirs at the standard XDG locations skips the
        # lookup and keeps the on-disk layout unchanged.
        "--run"
        "export FREECAD_USER_HOME=\"$HOME/.config/FreeCAD/${versionDir pkgs}\" FREECAD_USER_DATA=\"$HOME/.local/share/FreeCAD/${versionDir pkgs}\"; mkdir -p \"$FREECAD_USER_HOME\" \"$FREECAD_USER_DATA\""
      ];
    };

  versionDir =
    pkgs: "v${lib.replaceStrings [ "." ] [ "-" ] (lib.versions.majorMinor pkgs.freecad.version)}";

  homeCfg =
    { pkgs, lib }:
    let
      freecad = mkFreecad pkgs;
      catppuccin = catppuccinSrc pkgs;
      dir = versionDir pkgs;
      # XDG launchers only rescan a data dir when it changes, and the package's
      # own entry sits behind ~/.nix-profile — a symlink that is swapped on every
      # switch — so Activities search can miss it. Copy the entry into the stable
      # XDG dir and pin Exec to the wrapped binary instead of relying on PATH.
      desktopEntry = pkgs.runCommand "org.freecad.FreeCAD.desktop" { } ''
        mkdir -p $out/share/applications
        substitute ${freecad}/share/applications/org.freecad.FreeCAD.desktop \
          $out/share/applications/org.freecad.FreeCAD.desktop \
          --replace-fail "Exec=FreeCAD " "Exec=${freecad}/bin/freecad "
      '';
      # The FreeCADMCP add-on reads this file next to the user data dir and
      # starts its RPC server on 127.0.0.1:9875 at startup when auto_start_rpc
      # is set, so the OpenCode `freecad` server works without touching a
      # toolbar button. Written once, then owned by the user: the add-on saves
      # to it when toggling Auto Start / Remote connections.
      mcpSettings = pkgs.writeText "freecad_mcp_settings.json" (
        builtins.toJSON {
          remote_enabled = false;
          allowed_ips = "127.0.0.1";
          auto_start_rpc = true;
          auth_token = "";
        }
      );
    in
    {
      home.packages = [ freecad ];
      home.file = {
        ".local/share/applications/org.freecad.FreeCAD.desktop".source =
          "${desktopEntry}/share/applications/org.freecad.FreeCAD.desktop";
        ".local/share/FreeCAD/${dir}/Gui/Stylesheets/CatppuccinNights.qss".source =
          "${catppuccin}/CatppuccinNights/CatppuccinNights.qss";
        ".local/share/FreeCAD/${dir}/Gui/Stylesheets/images_dark-light".source =
          "${catppuccin}/CatppuccinNights/images_dark-light";
        ".local/share/FreeCAD/${dir}/Gui/Stylesheets/overlay".source =
          "${catppuccin}/CatppuccinNights/overlay";
      };
      home.activation.freecadPrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfgdir="$HOME/.config/FreeCAD/${dir}"
        if [ ! -f "$cfgdir/system.cfg" ]; then
          mkdir -p "$cfgdir"
          cp --no-preserve=mode,ownership "${catppuccin}/CatppuccinNights/CatppuccinNights.cfg" "$cfgdir/system.cfg"
        fi
        if [ ! -f "$cfgdir/user.cfg" ]; then
          mkdir -p "$cfgdir"
          cp --no-preserve=mode,ownership "${catppuccin}/CatppuccinPreferences/CatppuccinPreferences.cfg" "$cfgdir/user.cfg"
          $DRY_RUN_CMD ${freecad}/bin/freecadcmd -c "exec(open('${../../config/freecad/seed.py}').read())" >/dev/null 2>&1 || true
        fi
        # FreeCAD only exposes preference packs through the GUI, so the theme is
        # selected here instead. Re-applied whenever user.cfg no longer points at
        # the Catppuccin style sheet / overlay (first switch, or a manual change).
        if ! grep -qsF "Name=\"StyleSheet\">CatppuccinNights.qss" "$cfgdir/user.cfg" ||
          ! grep -qsF "Name=\"OverlayActiveStyleSheet\">CatppuccinNights_Overlay.qss" "$cfgdir/user.cfg"; then
          $DRY_RUN_CMD ${freecad}/bin/freecadcmd -c "exec(open('${../../config/freecad/theme.py}').read())" >/dev/null 2>&1 || true
        fi
        mcpfile="$HOME/.local/share/FreeCAD/${dir}/freecad_mcp_settings.json"
        if [ ! -f "$mcpfile" ]; then
          mkdir -p "$(dirname "$mcpfile")"
          $DRY_RUN_CMD install -m 0644 ${mcpSettings} "$mcpfile"
        fi
      '';
      xdg.mimeApps.defaultApplications."application/x-extension-fcstd" = "org.freecad.FreeCAD.desktop";
    };
in
{
  nixconf.modules.nixos.freecad =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.freecad.enable = lib.mkEnableOption "FreeCAD with 3D-print addons";
      config = lib.mkIf (config.modules.freecad.enable && pkgs.stdenv.hostPlatform.isLinux) {
        home-manager.users.${config.modules.users.userName} =
          { pkgs, lib, ... }:
          homeCfg { inherit pkgs lib; };
      };
    };

  nixconf.modules.homeManager.freecad =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.freecad.enable = lib.mkEnableOption "FreeCAD with 3D-print addons";
      config = lib.mkIf (config.modules.freecad.enable && pkgs.stdenv.hostPlatform.isLinux) (homeCfg {
        inherit pkgs lib;
      });
    };
}
