{lib, ...}: let
  containerAliases = {
    d = "docker";
    dc = "docker-compose";
    ld = "lazydocker";
    dru = "docker run -it --rm -v $NIXCONF:/root/nixconf ubuntu bash";
    ds = "devpod ssh";
    du = "devpod up .";
  };
in {
  flake.modules.nixos.containers = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.containers.enable = lib.mkEnableOption "Container tooling (devpod, docker-compose)";
    config = lib.mkIf config.modules.containers.enable {
      environment.systemPackages = with pkgs; [devpod docker-compose];
      home-manager.users.${config.modules.users.userName}.programs.zsh.shellAliases = containerAliases;
    };
  };

  flake.modules.homeManager.containers = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.containers.enable = lib.mkEnableOption "Container tooling (devpod, docker-compose)";
    config = lib.mkIf config.modules.containers.enable {
      home.packages = with pkgs; [devpod docker-compose];
      programs.zsh.shellAliases = containerAliases;
    };
  };
}
