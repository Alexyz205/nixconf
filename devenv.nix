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
    # Repo tooling (test suite prerequisites)
    disko
    shellcheck # bash linter (also a test-suite prerequisite)
    sops
    age-plugin-yubikey

    # markdown: LSP marksman, formatter prettierd, linter markdownlint-cli2
    marksman
    prettierd
    markdownlint-cli2

    # yaml: LSP yaml-language-server
    yaml-language-server

    # json: LSP vscode-json-languageserver
    vscode-json-languageserver

    # toml: LSP taplo
    taplo

    # nix: formatter nixfmt (LSP nil + linter statix via languages.nix)
    nixfmt

    # python: linter + formatter ruff (LSP basedpyright via languages.python)
    ruff

    # lua: formatter stylua, linter luacheck (LSP lua-language-server via languages.lua)
    stylua
    luaPackages.luacheck

    # terraform: linter tflint (LSP terraform-ls + formatter terraform fmt via languages.terraform)
    tflint

    # docker: LSP dockerfile-language-server-nodejs + docker-compose-language-service, linter hadolint
    dockerfile-language-server-nodejs
    docker-compose-language-service
    hadolint

    # cmake: LSP cmake-language-server, formatter gersemi (linter gersemi --check)
    cmake-language-server
    gersemi

    # arduino: build tool arduino-cli (LSP clangd + formatter clang-format + linter clang-tidy
    # come from languages.c/cplusplus below, applied to .ino via the clangd extra)
    arduino-cli
  ];

  delta.enable = true;

  # Language toolchains: compiler/runtime + matching LSP/linter/formatter.
  # Each `languages.*` battery pulls in the compiler/runtime AND its LSP;
  # linters/formatters that live in `packages` above are cross-referenced here.
  languages = {
    # nix: LSP nil, linter statix + deadnix (formatter nixfmt via packages)
    nix = {
      enable = true;
      lsp.package = pkgs.nil;
    };

    # python: LSP basedpyright (linter + formatter ruff via packages)
    python = {
      enable = true;
      lsp.package = pkgs.basedpyright;
    };

    # shell / bash: LSP bash-language-server, linter shellcheck, formatter shfmt
    shell.enable = true;

    # c: LSP clangd, formatter clang-format, linter clang-tidy (clang-tools)
    c = {
      enable = true;
      lsp.enable = false;
    };

    # c++: LSP clangd, formatter clang-format, linter clang-tidy; adds cmake + clang
    cplusplus = {
      enable = true;
      lsp.enable = false;
    };

    # lua: LSP lua-language-server (formatter stylua + linter luacheck via packages)
    lua.enable = true;

    # terraform: LSP terraform-ls, formatter terraform fmt, validate (linter tflint via packages)
    terraform.enable = true;

    # ansible: LSP ansible-language-server, linter ansible-lint
    ansible.enable = true;
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
    "test:iso" = {
      description = "Build the installer-iso image";
      exec = "./scripts/test-all.sh iso";
    };
    "repo:fmt" = {
      description = "Format the repo (nixfmt, shfmt, prettierd via treefmt)";
      exec = "treefmt";
    };
  };
}
