{lib, ...}: let
  basicPkgs = {pkgs}: with pkgs; [
    curl
    wget
    openssl
    ripgrep
    fd
    fastfetch
    dust
    duf
    yq
    jq
    tree-sitter
  ];
  securityPkgs = {pkgs}: with pkgs; [
    age
    sops
    gnupg
  ];
  devToolsPkgs = {pkgs}: with pkgs; [
    delta
    diff-so-fancy
    gh
    fabric-ai
    lazydocker
  ];
  desktopPkgs = {pkgs}: with pkgs; [
    vlc
    libreoffice
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
        security = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        devTools = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        desktop = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };

      config = lib.mkIf (config.modules.packages.basic || config.modules.packages.security || config.modules.packages.devTools || config.modules.packages.desktop) {
        environment.systemPackages =
          (lib.optionals config.modules.packages.basic (basicPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.security (securityPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.devTools (devToolsPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.desktop (desktopPkgs {inherit pkgs;}));
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
        security = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        devTools = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        desktop = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };

      config = lib.mkIf (config.modules.packages.basic || config.modules.packages.security || config.modules.packages.devTools || config.modules.packages.desktop) {
        home.packages =
          (lib.optionals config.modules.packages.basic (basicPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.security (securityPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.devTools (devToolsPkgs {inherit pkgs;}))
          ++ (lib.optionals config.modules.packages.desktop (desktopPkgs {inherit pkgs;}));
      };
    };
  };
}
