{
  inputs,
  ...
}:
{
  # GP Connect's CLI (`gpclient`) is GPL-3.0; the desktop GUI in the same
  # release is a commercial product, but this module only exposes the CLI.
  # Nixpkgs removed the old Qt5 build, so the upstream flake (prebuilt, hash
  # pinned by its own lock) is the maintained source.
  flake-file.inputs.globalprotect-openconnect = {
    url = "github:yuezk/GlobalProtect-openconnect";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixconf.modules.homeManager.globalprotect =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.globalprotect;
      package = inputs.globalprotect-openconnect.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # `gpclient` talks to `gpservice` through pkexec, so the sign-in browser
      # runs in the user's session while only the tunnel setup is privileged.
      # Okta/WebAuthn needs a real browser; the embedded webview is not enough.
      gpvpn = pkgs.writeShellScriptBin "gpvpn" ''
        set -eu
        pkg=${package}

        case "''${1:-}" in
          disconnect|launch-gui|hip|diagnostics|help)
            exec "$pkg/bin/gpclient" "$@"
            ;;
          connect)
            shift
            if [ "$#" -eq 0 ]; then
              set -- ${lib.escapeShellArg cfg.portal}
            fi
            ;;
          "")
            set -- ${lib.escapeShellArg cfg.portal}
            ;;
        esac

        # `--browser` takes an optional value, so it must come after the
        # server. Do not duplicate it when the caller already passed one.
        has_browser=0
        for arg in "$@"; do
          case "$arg" in
            --browser|--browser=*) has_browser=1 ;;
          esac
        done

        args=(connect "$@")
        ${lib.optionalString cfg.browser ''
          if [ "$has_browser" -eq 0 ]; then
            args+=(--browser)
          fi
        ''}
        exec "$pkg/bin/gpclient" "''${args[@]}"
      '';

      # Escape hatch for hosts where pkexec/polkit is unavailable. Sign-in then
      # runs as root and may not reach the user's browser session.
      gpvpn-sudo = pkgs.writeShellScriptBin "gpvpn-sudo" ''
        exec sudo ${package}/bin/gpclient "$@"
      '';
    in
    {
      options.modules.globalprotect = {
        enable = lib.mkEnableOption "GlobalProtect VPN client (gpclient CLI)";
        portal = lib.mkOption {
          type = lib.types.str;
          default = "vpn.take2games.com";
          description = "Default GlobalProtect portal used by `gpvpn` when no argument is given.";
        };
        browser = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use the external browser for SAML/SSO (recommended for Okta and WebAuthn/YubiKey).";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [
          package
          gpvpn
          gpvpn-sudo
        ];
      };
    };
}
