_: {
  nixconf.modules.darwin.system =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.darwin.system.enable = lib.mkEnableOption "macOS base system settings";
      config = lib.mkIf config.modules.darwin.system.enable {
        # Create /etc/zshrc that loads the nix-darwin environment.
        programs.zsh.enable = true;
        environment.shells = [ pkgs.zsh ];
        time.timeZone = "Europe/Paris";
        networking = {
          knownNetworkServices = [
            "Wi-Fi"
            "Ethernet"
          ];
          # Friendly name for Sharing/AirDrop/scutil; hostName comes from
          # mkDarwinCommon, so keep all three in sync.
          computerName = config.networking.hostName;
          localHostName = config.networking.hostName;
        };
        # Homebrew first so brew-installed binaries win over nix ones.
        environment.systemPath = lib.mkBefore [
          "/opt/homebrew/bin"
          "/opt/homebrew/sbin"
        ];
      };
    };
}
