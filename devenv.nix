# Dev environment for the nixconf repo itself.
#
# Purpose: provide the test prerequisites used by `scripts/test-all.sh`
#   (test_disko needs `disko`, test_shellcheck needs `shellcheck`).
# Devenv also gives auto-activation when you `cd` into this repo.
#
# LSPs / formatters for LazyVim now live HERE (not in the lazyvim module):
# every repo owns its LSPs and LazyVim picks them up from $PATH via devenv
# auto-activation. This file is also the reference template for new repos.
{ pkgs, ... }: {
  name = "nixconf";

  env = {
    TERM = "screen-256color";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  packages = with pkgs; [
    disko
    shellcheck
    sops
    age-plugin-yubikey

    # LSPs / formatters that have no devenv `languages.*` module.
    marksman
    yaml-language-server
    vscode-json-languageserver
    taplo
    ruff
    prettierd
    markdownlint-cli
    nixfmt
  ];

  delta.enable = true;

  # Language toolchains: compiler/runtime + matching LSP.
  # nix → statix, deadnix, vulnix + nil (override from default nixd).
  # python → python + pip + basedpyright (override from default pyright).
  # shell → shellcheck, shfmt, bats + bash-language-server.
  languages = {
    nix = {
      enable = true;
      lsp.package = pkgs.nil;
    };
    python = {
      enable = true;
      lsp.package = pkgs.basedpyright;
    };
    shell.enable = true;
  };

  # Repo-wide formatters (nix / markdown / bash) via treefmt. Same tools LazyVim
  # uses: nixfmt (nix), prettierd (markdown), shfmt (sh). Run `treefmt` in
  # `devenv shell` to apply.
  treefmt = {
    enable = true;
    config = {
      programs = {
        nixfmt.enable = true;
        shfmt.enable = true;
      };
      # prettierd reads stdin and takes the filename as a positional arg, so
      # wrap it to write in place (treefmt's contract).
      settings.formatter.prettierd = {
        command = "${pkgs.bash}/bin/bash";
        options = [
          "-euc"
          ''
            for file in "$@"; do
              ${pkgs.prettierd}/bin/prettierd "$file" < "$file" > "$file.prettierd.tmp" || exit 1
              mv "$file.prettierd.tmp" "$file"
            done
          ''
          "--"
        ];
        includes = [
          "*.md"
          "*.mdx"
        ];
        excludes = [
          ".git/*"
          ".devenv/*"
        ];
      };
    };
  };

  # Project commands: `devenv tasks run <name>` (also reachable through the tv
  # `devenv-tasks` channel). Mirrors scripts/test-all.sh plus common workflows.
  tasks = {
    "test:all" = {
      description = "Run the full test suite (scripts/test-all.sh)";
      exec = "./scripts/test-all.sh";
    };
    "test:flake" = {
      description = "nix flake check (all configs, options, checks)";
      exec = "nix flake check";
    };
    "test:eval" = {
      description = "Dry-run eval every NixOS + home-manager config";
      exec = "./scripts/test-all.sh eval";
    };
    "test:disko" = {
      description = "Disko dry-run for workstation & headless-worker";
      exec = "./scripts/test-all.sh disko";
    };
    "test:iso" = {
      description = "Build the installer-iso image";
      exec = "./scripts/test-all.sh iso";
    };
    "test:vm" = {
      description = "Build the Proxmox VM image (.#proxmox-vm)";
      exec = "./scripts/test-all.sh vm";
    };
    "test:shellcheck" = {
      description = "Lint scripts/*.sh with shellcheck";
      exec = "./scripts/test-all.sh shellcheck";
    };
    "repo:fmt" = {
      description = "Format the repo (nixfmt, shfmt, prettierd via treefmt)";
      exec = "treefmt";
    };
    "repo:fmt-check" = {
      description = "Verify formatting without applying (CI-style)";
      exec = "treefmt --fail-on-change";
    };
    "repo:lint" = {
      description = "Static analysis: statix, deadnix, shellcheck";
      exec = "statix check && deadnix -f . && shellcheck -S warning scripts/*.sh";
    };
    "repo:update" = {
      description = "Update flake lockfile inputs (nix flake update)";
      exec = "nix flake update";
    };
    "repo:lock" = {
      description = "Refresh the flake lock without updating inputs";
      exec = "nix flake lock";
    };
  };

  enterShell = ''
    echo "nixconf dev environment — run 'devenv tasks run <name>':"
    echo "  test:all, test:{flake,eval,disko,iso,vm,shellcheck}  repo:{fmt,fmt-check,lint,update,lock}"
  '';
}
