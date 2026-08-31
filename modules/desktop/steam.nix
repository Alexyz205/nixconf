{
  lib,
  ...
}:
let
  audioBlockSrc = builtins.toFile "audio-block.c" ''
    #define _GNU_SOURCE
    #include <dlfcn.h>
    #include <string.h>

    static int blocked(const char *filename) {
      return filename &&
        (strstr(filename, "libaudio.so") || strstr(filename, "libaudiopacket.so"));
    }

    void *dlopen(const char *filename, int flags) {
      static void *(*real)(const char *, int) = 0;
      if (blocked(filename)) return 0;
      if (!real) real = (void *(*)(const char *, int)) dlsym(RTLD_NEXT, "dlopen");
      return real(filename, flags);
    }

    void *dlmopen(Lmid_t lmid, const char *filename, int flags) {
      static void *(*real)(Lmid_t, const char *, int) = 0;
      if (blocked(filename)) return 0;
      if (!real) real = (void *(*)(Lmid_t, const char *, int)) dlsym(RTLD_NEXT, "dlmopen");
      return real(lmid, filename, flags);
    }
  '';

  mkAudioBlock =
    pkgs:
    pkgs.stdenv.mkDerivation {
      pname = "steam-audio-block";
      version = "1.0";
      src = audioBlockSrc;
      unpackPhase = ":";
      dontConfigure = true;
      dontFixup = true;
      buildPhase = "gcc -shared -fPIC -o libaudio-block.so $src -ldl";
      installPhase = "mkdir -p $out/lib; cp libaudio-block.so $out/lib/";
    };
in
{
  flake.modules.nixos.steam =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.steam.enable = lib.mkEnableOption "Steam";
      config = lib.mkIf config.modules.steam.enable {
        programs.steam.enable = true;
        # Steam's CEF (web view) renders black / no window under niri's XWayland
        # when GPU-accelerated. -system-composer (niri-recommended) renders the UI
        # via the compositor instead. See niri "Application-Specific Issues: Steam".
        #
        # Crash fix: the client segfaults in its bundled libaudio.so's PulseAudio
        # callback on pipewire-pulse (ValveSoftware/steam-for-linux#13174). The
        # LD_PRELOAD shim makes dlopen/dlmopen of libaudio.so fail so the client
        # skips audio init instead of crashing. This is scoped to the client only:
        # games never load Steam's libaudio.so, so they get a clean environment
        # and real PulseAudio (the old PULSE_SERVER=/nonexistent workaround was
        # inherited by spawned games and broke their audio).
        programs.steam.package = pkgs.steam.override {
          extraArgs = "-system-composer";
          extraEnv = {
            # 32-bit client only: the 64-bit webhelper ignores the mismatched arch.
            # /nix is bind-mounted into the FHS container, so the store path resolves.
            LD_PRELOAD = "${mkAudioBlock pkgs.pkgsi686Linux}/lib/libaudio-block.so";
          };
        };
      };
    };
}
