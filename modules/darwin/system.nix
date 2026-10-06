_: {
  flake.modules.darwin.system =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.system.enable = lib.mkEnableOption "macOS base system settings";
      config = lib.mkIf config.modules.system.enable {
        # Create /etc/zshrc that loads the nix-darwin environment.
        programs.zsh.enable = true;
        environment.shells = [ pkgs.zsh ];
        time.timeZone = "Europe/Paris";
        networking.knownNetworkServices = [
          "Wi-Fi"
          "Ethernet"
        ];
        # Homebrew first so brew-installed binaries win over nix ones.
        environment.systemPath = lib.mkBefore [
          "/opt/homebrew/bin"
          "/opt/homebrew/sbin"
        ];
      };
    };
}
