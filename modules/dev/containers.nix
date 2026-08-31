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
  dotfilesScript = "scripts/install.sh container -y";
  # Idempotent devpod setup script - runs at activation, only applies missing config.
  devpodEnsure =
    { config, lib, ... }:
    let
      cfgFile = "${config.home.homeDirectory}/.devpod/config.yaml";
      ensure = ''
        ensure_devpod() {
          command -v devpod >/dev/null 2>&1 || return 0
          if ! grep -q 'DOTFILES_URL' "$HOME/.devpod/config.yaml" 2>/dev/null; then
            devpod context set-options \
              -o DOTFILES_URL='https://github.com/Alexyz205/nixconf.git' \
              -o DOTFILES_SCRIPT='scripts/install.sh container -y' >/dev/null 2>&1 || true
          fi
          if ! devpod provider list 2>/dev/null | grep -q docker; then
            devpod provider add docker >/dev/null 2>&1 || true
          fi
          devpod provider use docker >/dev/null 2>&1 || true
        }
        ensure_devpod
      '';
    in
    {
      home.activation.setupDevpod = config.lib.dag.entryAfter [ "writeBoundary" ] ensure;
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
        home-manager.users.${config.modules.users.userName} = {
          programs.zsh.shellAliases = {
            d = "docker";
            dc = "docker-compose";
            ld = "lazydocker";
            dru = "docker run -it --rm -v $NIXCONF:/root/nixconf ubuntu bash";
            ds = "devpod ssh";
            du = "devpod up .";
          };
          home.activation.setupDevpod = ''
            ensure_devpod() {
              command -v devpod >/dev/null 2>&1 || return 0
              if ! grep -q 'DOTFILES_URL' "$HOME/.devpod/config.yaml" 2>/dev/null; then
                devpod context set-options \
                  -o DOTFILES_URL='https://github.com/Alexyz205/nixconf.git' \
                  -o DOTFILES_SCRIPT='scripts/install.sh container -y' >/dev/null 2>&1 || true
              fi
              if ! devpod provider list 2>/dev/null | grep -q docker; then
                devpod provider add docker >/dev/null 2>&1 || true
              fi
              devpod provider use docker >/dev/null 2>&1 || true
            }
            ensure_devpod
          '';
        };
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
      config = lib.mkIf config.modules.containers.enable {
        home.packages = with pkgs; [
          devpod
          docker-compose
        ];
        programs.zsh.shellAliases = {
          d = "docker";
          dc = "docker-compose";
          ld = "lazydocker";
          ds = "devpod ssh";
          du = "devpod up .";
        };
        home.activation.setupDevpod = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          ensure_devpod() {
            command -v devpod >/dev/null 2>&1 || return 0
            if ! grep -q 'DOTFILES_URL' "$HOME/.devpod/config.yaml" 2>/dev/null; then
              devpod context set-options \
                -o DOTFILES_URL='https://github.com/Alexyz205/nixconf.git' \
                -o DOTFILES_SCRIPT='scripts/install.sh container -y' >/dev/null 2>&1 || true
            fi
            if ! devpod provider list 2>/dev/null | grep -q docker; then
              devpod provider add docker >/dev/null 2>&1 || true
            fi
            devpod provider use docker >/dev/null 2>&1 || true
          }
          ensure_devpod
        '';
      };
    };
}
