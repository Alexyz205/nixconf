{lib, ...}: let
  basicPkgs = {pkgs}: with pkgs; [
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
    jq
    tree-sitter
  ];
  containerPkgs = {pkgs}: with pkgs; [
    devpod
    docker-compose
  ];
  securityPkgs = {pkgs}: with pkgs; [
    pass
    age
    sops
    gnupg
  ];
  devToolsPkgs = {pkgs}: with pkgs; [
    delta
    diff-so-fancy
    gh
    glab
    # opencode
    fabric-ai
    lazydocker
    devenv
  ];
in {
  flake.modules = {
    nixos.packages = {
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
          (lib.optionals config.modules.packages.basic (basicPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.containers (containerPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.security (securityPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.devTools (devToolsPkgs {inherit pkgs;}));
      };
    };

    homeManager.packages = {
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
        home.packages =
          (lib.optionals config.modules.packages.basic (basicPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.containers (containerPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.security (securityPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.devTools (devToolsPkgs {inherit pkgs;}));
      };
    };
  };
}
