_: {
  nixconf.modules.darwin.security =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.darwin.security.enable = lib.mkEnableOption "macOS security settings";
      config = lib.mkIf config.modules.darwin.security.enable {
        # Use Touch ID for sudo authentication.
        security.pam.services.sudo_local.touchIdAuth = true;
        networking.applicationFirewall = {
          enable = true;
          allowSigned = true;
          allowSignedApp = true;
          enableStealthMode = true;
        };
        # Vim-friendly: caps lock becomes escape.
        system.keyboard = {
          enableKeyMapping = true;
          remapCapsLockToEscape = true;
        };
      };
    };
}
