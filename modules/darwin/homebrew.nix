_: {
  nixconf.modules.darwin.homebrew =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.darwin.homebrew.enable = lib.mkEnableOption "Homebrew";
      config = lib.mkIf config.modules.darwin.homebrew.enable {
        homebrew = {
          enable = true;
          onActivation = {
            # Keep rebuilds idempotent/offline (nix-darwin's default).
            autoUpdate = false;
            # Never upgrade on activation: keep the environment stable.
            upgrade = false;
            cleanup = "zap";
          };
          # Also stop Homebrew auto-updating itself on manual `brew` runs.
          global.autoUpdate = false;
          brews = [
            "openssh"
            "libfido2"
          ];
          casks = [
            "cap"
            "ghostty"
            "macfuse"
          ];
          masApps = { };
        };
      };
    };
}
