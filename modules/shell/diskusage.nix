let
  diskPackages =
    pkgs: with pkgs; [
      dust
      duf
    ];
  diskAliases = {
    dst = "dust";
    dsz = "dust -d 1";
  };
  homeCfg = pkgs: {
    home.packages = diskPackages pkgs;
    programs.zsh.shellAliases = diskAliases;
  };
in
_: {
  nixconf.modules.nixos.diskusage =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.diskusage.enable = lib.mkEnableOption "Disk usage tooling (dust, duf)";
      config = lib.mkIf config.modules.diskusage.enable {
        environment.systemPackages = diskPackages pkgs;
        home-manager.users.${config.modules.users.userName} = homeCfg pkgs;
      };
    };

  nixconf.modules.homeManager.diskusage =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.diskusage.enable = lib.mkEnableOption "Disk usage tooling (dust, duf)";
      config = lib.mkIf config.modules.diskusage.enable (homeCfg pkgs);
    };
}
