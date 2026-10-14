let
  palette = import ../../config/theme/catppuccin-mocha.nix;
  # btop dlopens libnvidia-ml at startup to show GPU usage. A nix-built binary
  # has no path to a non-NixOS host's driver, so on Linux we wrap it to preload
  # the first libnvidia-ml we find (NixOS driver dir, then common distro paths).
  # Where no NVIDIA driver exists the loop is a no-op and btop stays CPU-only.
  mkBtop =
    pkgs: cudaSupport:
    let
      base = pkgs.btop.override { inherit cudaSupport; };
    in
    if pkgs.stdenv.hostPlatform.isLinux then
      pkgs.writeShellScriptBin "btop" ''
        for dir in /run/opengl-driver/lib /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib /usr/lib/aarch64-linux-gnu; do
          if [ -e "$dir/libnvidia-ml.so.1" ]; then
            export LD_PRELOAD="$dir/libnvidia-ml.so.1''${LD_PRELOAD:+:$LD_PRELOAD}"
            break
          fi
        done
        exec ${base}/bin/btop "$@"
      ''
    else
      base;

  btopCfg =
    {
      pkgs,
      cudaSupport,
      ...
    }:
    {
      programs.btop = {
        enable = true;
        package = mkBtop pkgs cudaSupport;
        settings = {
          theme_background = false;
          vim_keys = true;
          color_theme = "catppuccin_mocha";
          gpu_usage = true;
        };
      };
      home.file.".config/btop/themes/catppuccin_mocha.theme".text = ''
        # Generated from config/theme/catppuccin-mocha.nix — do not edit by hand.
        theme[main_bg]="${palette.base}"
        theme[main_fg]="${palette.text}"
        theme[title]="${palette.text}"
        theme[hi_fg]="${palette.blue}"
        theme[selected_bg]="${palette.surface1}"
        theme[selected_fg]="${palette.blue}"
        theme[inactive_fg]="${palette.overlay1}"
        theme[graph_text]="${palette.rosewater}"
        theme[meter_bg]="${palette.surface1}"
        theme[proc_misc]="${palette.rosewater}"
        theme[cpu_box]="${palette.mauve}"
        theme[mem_box]="${palette.green}"
        theme[net_box]="${palette.maroon}"
        theme[proc_box]="${palette.blue}"
        theme[div_line]="${palette.overlay0}"
        theme[temp_start]="${palette.green}"
        theme[temp_mid]="${palette.yellow}"
        theme[temp_end]="${palette.red}"
        theme[cpu_start]="${palette.teal}"
        theme[cpu_mid]="${palette.sapphire}"
        theme[cpu_end]="${palette.lavender}"
        theme[free_start]="${palette.mauve}"
        theme[free_mid]="${palette.lavender}"
        theme[free_end]="${palette.blue}"
        theme[cached_start]="${palette.sapphire}"
        theme[cached_mid]="${palette.blue}"
        theme[cached_end]="${palette.lavender}"
        theme[available_start]="${palette.peach}"
        theme[available_mid]="${palette.maroon}"
        theme[available_end]="${palette.red}"
        theme[used_start]="${palette.green}"
        theme[used_mid]="${palette.teal}"
        theme[used_end]="${palette.sky}"
        theme[download_start]="${palette.peach}"
        theme[download_mid]="${palette.maroon}"
        theme[download_end]="${palette.red}"
        theme[upload_start]="${palette.green}"
        theme[upload_mid]="${palette.teal}"
        theme[upload_end]="${palette.sky}"
        theme[process_start]="${palette.sapphire}"
        theme[process_mid]="${palette.lavender}"
        theme[process_end]="${palette.mauve}"
      '';
    };

  btopOptions = lib: {
    enable = lib.mkEnableOption "Btop";
    # CUDA support pulls the NVIDIA stack and is only meaningful on hosts with
    # an NVIDIA GPU; default off so macOS/containers/CPU-only Linux stay light.
    cudaSupport = lib.mkEnableOption "Btop CUDA (NVIDIA GPU) support";
  };
in
_: {
  nixconf.modules.nixos.btop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.btop = btopOptions lib;
      config = lib.mkIf config.modules.btop.enable (
        let
          cudaSupport = config.modules.btop.cudaSupport;
        in
        {
          environment.systemPackages = [ (mkBtop pkgs cudaSupport) ];
          # Hand home-manager its own module args; carry the NixOS-side
          # cudaSupport across so both sides build the same btop.
          home-manager.users.${config.modules.users.userName} =
            {
              pkgs,
              config,
              ...
            }:
            btopCfg { inherit pkgs config cudaSupport; };
        }
      );
    };

  nixconf.modules.homeManager.btop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.btop = btopOptions lib;
      config = lib.mkIf config.modules.btop.enable (btopCfg {
        inherit pkgs config;
        inherit (config.modules.btop) cudaSupport;
      });
    };
}
