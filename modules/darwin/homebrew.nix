_: {
  flake.modules.darwin.homebrew =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.homebrew.enable = lib.mkEnableOption "Homebrew";
      config = lib.mkIf config.modules.homebrew.enable {
        homebrew = {
          enable = true;
          onActivation = {
            autoUpdate = true;
            # Never upgrade on activation: keep the environment stable.
            upgrade = false;
            cleanup = "zap";
          };
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
