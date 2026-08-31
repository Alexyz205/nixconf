{ lib, ... }:
let
  mkPackages =
    {
      config,
      lib,
      pkgs,
    }:
    let
      groups = with pkgs; {
        basic = [
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
        security = [
          age
          sops
          gnupg
        ];
        devTools = [
          delta
          diff-so-fancy
          gh
          fabric-ai
          lazydocker
        ];
        desktop = [
          vlc
          libreoffice
        ];
      };
      enabled = n: config.modules.packages.${n};
      order = [
        "basic"
        "security"
        "devTools"
        "desktop"
      ];
    in
    {
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
      # Non-empty when any group is enabled (all groups are non-empty).
      packageList = lib.concatLists (map (n: lib.optionals (enabled n) groups.${n}) order);
    };
in
{
  flake.modules.nixos.packages =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      p = mkPackages { inherit config lib pkgs; };
    in
    {
      inherit (p) options;
      config = lib.mkIf (p.packageList != [ ]) {
        environment.systemPackages = p.packageList;
      };
    };

  flake.modules.homeManager.packages =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      p = mkPackages { inherit config lib pkgs; };
    in
    {
      inherit (p) options;
      config = lib.mkIf (p.packageList != [ ]) {
        home.packages = p.packageList;
      };
    };
}