_:
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
        # LSPs / formatters / linters on every host + home-manager profile so the
        # tooling is on $PATH regardless of the dev environment.
        lsp = [
          marksman
          prettierd
          markdownlint-cli2
          shfmt
          shellcheck
          bash-language-server
          helm-ls
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
        "lsp"
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
          description = "Core CLI utilities.";
        };
        lsp = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "LSPs, formatters and linters for the languages in use.";
        };
        security = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Security and encryption tooling.";
        };
        devTools = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Developer productivity tools.";
        };
        desktop = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Desktop applications.";
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
