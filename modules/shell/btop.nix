let
  mkBtop = pkgs: cudaSupport: pkgs.btop.override { inherit cudaSupport; };

  btopCfg =
    {
      pkgs,
      config,
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
      home.file.".config/btop/themes/catppuccin_mocha.theme".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/btop/catppuccin_mocha.theme";
    };

  btopOptions = lib: {
    enable = lib.mkEnableOption "Btop";
    # CUDA support pulls the NVIDIA stack and is only meaningful on hosts with
    # an NVIDIA GPU; default off so macOS/containers/CPU-only Linux stay light.
    cudaSupport = lib.mkEnableOption "Btop CUDA (NVIDIA GPU) support";
  };
in
_: {
  flake.modules.nixos.btop =
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

  flake.modules.homeManager.btop =
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
