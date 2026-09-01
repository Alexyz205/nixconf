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
        markdown = [
          marksman
          prettierd
          markdownlint-cli2
        ];
        security = [
          age
          sops
          gnupg
        ];
        devTools = [
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
        "markdown"
        "security"
        "devTools"
        "desktop"
      ];
    in
    {
      options.modules.packages = {
        basic = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Core CLI utilities: curl, wget, openssl, ripgrep, fd, fastfetch, dust, duf, yq, jq, tree-sitter.";
        };
        markdown = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Markdown tooling: marksman LSP, prettierd formatter, markdownlint-cli2 linter.";
        };
        security = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Security tooling: age, sops, gnupg.";
        };
        devTools = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Dev tooling: fabric-ai, lazydocker.";
        };
        desktop = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Desktop applications: vlc, libreoffice.";
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
