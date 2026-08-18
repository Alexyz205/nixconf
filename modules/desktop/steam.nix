{
  lib,
  ...
}: {
  flake.modules.nixos.steam = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.steam.enable = lib.mkEnableOption "Steam";
    config = lib.mkIf config.modules.steam.enable {
      programs.steam.enable = true;
      # Steam's CEF (web view) renders black / no window under niri's XWayland
      # when GPU-accelerated. -system-composer (niri-recommended) renders the UI
      # via the compositor instead. See niri "Application-Specific Issues: Steam".
      programs.steam.package = pkgs.steam.override {
        extraArgs = "-system-composer";
        # Steam client segfaults at startup in its bundled libaudio.so via the
        # PulseAudio threaded-mainloop when talking to pipewire-pulse
        # (ValveSoftware/steam-for-linux#13174, still open in Jul 2026 builds).
        # Make PulseAudio unreachable for the client only; game audio is unaffected.
        extraEnv.PULSE_SERVER = "/nonexistent";
      };
    };
  };
}