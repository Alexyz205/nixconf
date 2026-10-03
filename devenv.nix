# Dev environment for the nixconf repo itself.
#
# Purpose: provide the test prerequisites used by `scripts/test-all.sh`
#   (test_disko needs `disko`, test_shellcheck needs `shellcheck`).
# Devenv also gives auto-activation when you `cd` into this repo.
#
# LSPs / formatters for LazyVim now live HERE (not in the lazyvim module):
# every repo owns its LSPs and LazyVim picks them up from $PATH via devenv
# auto-activation.
#
# This file is kept to ONLY what this repo needs. The full commented template
# for copying into other repos lives at `examples/devenv.nix`.
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

    # nix: formatter nixfmt (LSP nil + linter statix via languages.nix)
    nixfmt

    # yaml: LSP yaml-language-server (secrets, devenv.yaml, .sops.yaml, theme.yml)
    yaml-language-server

    # lua: formatter stylua, linter luacheck (LSP lua-language-server via languages.lua)
    stylua
    luaPackages.luacheck
  ];

  # Language toolchains: compiler/runtime + matching LSP/linter/formatter.
  languages = {
    # nix: LSP nil, linter statix + deadnix (formatter nixfmt via packages)
    nix = {
      enable = true;
      lsp.package = pkgs.nil;
    };

    # shell / bash: LSP bash-language-server, linter shellcheck, formatter shfmt
    shell.enable = true;

    # lua: LSP lua-language-server (formatter stylua + linter luacheck via packages)
    lua.enable = true;
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

  # Git hooks managed by devenv (prek shims auto-installed into .git/hooks/ on
  # `devenv shell` entry). Three layers:
  #   1. fast per-file staged linting on commit (shellcheck, nixfmt, ...)
  #   2. the fast full-suite gate on commit (flake, eval, shellcheck)
  #   3. the slow image-build gate on push (disko, iso, vm)
  # Layers 2-3 are custom `always_run` hooks that mirror scripts/test-all.sh;
  # they re-enter via `devenv shell` when tools are missing.
  git-hooks = {
    enable = true;
    hooks = {
      shellcheck = {
        enable = true;
        # shellcheck can't parse zsh; only lint real sh/bash scripts.
        files = "\\.(sh|bash)$";
      };
      shfmt = {
        enable = true;
        # Match the repo's treefmt shfmt settings (-i 2 -s), and skip zsh.
        files = "\\.(sh|bash)$";
        settings.indent = 2;
        settings.simplify = true;
      };
      nixfmt.enable = true;
      statix = {
        enable = true;
        # See statix.toml: repeated_keys is disabled (import-tree design).
        settings.config = "statix.toml";
      };
      deadnix.enable = true;
      luacheck.enable = true;
      stylua.enable = true;

      nixconf-fast = {
        enable = true;
        name = "nixconf fast suite (flake, eval, shellcheck)";
        entry = "${pkgs.bash}/bin/bash ./scripts/test-all.sh flake eval shellcheck";
        language = "system";
        pass_filenames = false;
        always_run = true;
        stages = [ "pre-commit" ];
      };

      nixconf-slow = {
        enable = true;
        name = "nixconf slow suite (disko, iso, vm)";
        entry = "${pkgs.bash}/bin/bash ./scripts/test-all.sh disko iso vm";
        language = "system";
        pass_filenames = false;
        always_run = true;
        stages = [ "pre-push" ];
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

  # Generate `.devcontainer/devcontainer.json`. The base image has no Nix nor
  # devenv, so the Nix feature installs both (flakes enabled) and the direnv
  # extension enables devenv auto-activation inside the container.
  devcontainer = {
    enable = true;
    settings = {
      image = "mcr.microsoft.com/devcontainers/base:ubuntu-24.04";
    };
  };

  containers."test" = {
    startupCommand = "${pkgs.nix}/bin/nix flake check";
  };
}
