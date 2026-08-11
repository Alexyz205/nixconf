{lib, ...}: {
  flake.modules.nixos.packages = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.packages = {
      basic = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      containers = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      security = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      devTools = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };

    config = lib.mkIf (config.modules.packages.basic || config.modules.packages.containers || config.modules.packages.security || config.modules.packages.devTools) {
      environment.systemPackages =
        (lib.optionals config.modules.packages.basic (with pkgs; [
          curl
          wget
          openssl
          ripgrep
          fd
          bat
          eza
          television
          fastfetch
          dust
          duf
          yq
          dasel
          jq
          tree-sitter
        ]))
        ++ (lib.optionals config.modules.packages.containers (with pkgs; [
          devpod
          docker-compose
          podman-compose
          lazydocker
        ]))
        ++ (lib.optionals config.modules.packages.security (with pkgs; [
          pass
          age
          sops
          gnupg
        ]))
        ++ (lib.optionals config.modules.packages.devTools (with pkgs; [
          delta
          diff-so-fancy
          gh
          glab
          opencode
          fabric-ai
          lazydocker
          lazyssh
          devenv
        ]));
    };
  };
}
