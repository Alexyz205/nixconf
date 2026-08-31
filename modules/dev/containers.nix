{
  lib,
  ...
}:
let
  containerAliases = {
    d = "docker";
    dc = "docker-compose";
    ld = "lazydocker";
    dru = "docker run -it --rm -v $NIXCONF:/root/nixconf ubuntu bash";
    ds = "devpod ssh";
    du = "devpod up .";
  };
  dotfilesUrl = "https://github.com/Alexyz205/nixconf.git";
  # devpod runs the script with `exec.Command`, so args would be re-parsed as
  # its own CLI flags — keep this a bare path. Non-interactive bootstraps
  # auto-answer the prompts (see install.sh `confirm`).
  dotfilesScript = "scripts/install.sh";
  # Idempotent devpod setup script - re-applying the same values is a no-op,
  # but keeps stale context options (e.g. an old DOTFILES_SCRIPT) in sync.
  devpodEnsure = ''
    ensure_devpod() {
      command -v devpod >/dev/null 2>&1 || return 0
      devpod context set-options \
        -o DOTFILES_URL='${dotfilesUrl}' \
        -o DOTFILES_SCRIPT='${dotfilesScript}' \
        -o SSH_CONFIG_PATH='~/.config/devpod/ssh_config' >/dev/null 2>&1 || true
      if ! devpod provider list 2>/dev/null | grep -q docker; then
        devpod provider add docker >/dev/null 2>&1 || true
      fi
      devpod provider use docker >/dev/null 2>&1 || true
    }
    ensure_devpod
  '';
  # Home-manager side shared by NixOS hosts and standalone profiles.
  homeConfig =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        devpod
        docker-compose
      ];
      programs.zsh.shellAliases = containerAliases;
      home.activation.setupDevpod = devpodEnsure;
    };
in
{
  flake.modules.nixos.containers =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.containers.enable = lib.mkEnableOption "Container tooling (devpod, docker-compose)";
      config = lib.mkIf config.modules.containers.enable {
        # Rootless podman (docker provider) needs the tun module for
        # slirp4netns/pasta networking, and unqualified-search-registries so
        # short image names (ubuntu:24.04) resolve.
        boot.kernelModules = [ "tun" ];
        virtualisation.containers.registries.settings.unqualified-search-registries = [ "docker.io" ];
        environment.systemPackages = with pkgs; [
          devpod
          docker-compose
        ];
        home-manager.users.${config.modules.users.userName} = homeConfig { inherit pkgs; };
      };
    };

  flake.modules.homeManager.containers =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.containers.enable = lib.mkEnableOption "Container tooling (devpod, docker-compose)";
      config = lib.mkIf config.modules.containers.enable (homeConfig {
        inherit pkgs;
      });
    };
}
