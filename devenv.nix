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

    # CI / YAML / secrets checks (mirrored by checks.lint and the git hooks)
    actionlint
    gitleaks
    yamllint
    trivy
    tokei

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
  # `devenv shell` entry). Layers:
  #   1. fast per-file staged linting on commit (shellcheck, nixfmt, ...)
  #   2. the fast full-suite gate on push (flake, eval, shellcheck)
  #   3. the slow image-build gate on push (disko, iso, vm)
  # Layer 1 stays on commit so committing is fast; layers 2-3 run on push
  # (a full flake check alone is ~60s warm). They re-enter via `devenv shell`
  # when tools are missing.
  #
  # Explicit `priority` (prek-only; devenv defaults `git-hooks.package` to
  # pkgs.prek) pins the run order: ascending priority, equal priority runs in
  # parallel, and each group is a barrier so later groups see formatted files.
  # Without it, prek derives priority from the hook's index in the generated
  # config (alphabetical), which ran the test suite before nixfmt.
  #   0  format  - mutating formatters, disjoint file sets -> parallel
  #   10 lint    - read-only linters -> parallel, after formatting
  #   20 test    - fast full-suite gate, alone, after format + lint
  #   30 slow    - image builds, alone, after the fast gate
  git-hooks = {
    enable = true;
    hooks = {
      shellcheck = {
        enable = true;
        # shellcheck can't parse zsh; only lint real sh/bash scripts.
        files = "\\.(sh|bash)$";
        priority = 10;
      };
      shfmt = {
        enable = true;
        # Match the repo's treefmt shfmt settings (-i 2 -s), and skip zsh.
        files = "\\.(sh|bash)$";
        settings.indent = 2;
        settings.simplify = true;
        priority = 0;
      };
      nixfmt = {
        enable = true;
        priority = 0;
      };
      statix = {
        enable = true;
        # See statix.toml: repeated_keys is disabled (import-tree design).
        settings.config = "statix.toml";
        priority = 10;
      };
      deadnix = {
        enable = true;
        priority = 10;
      };
      luacheck = {
        enable = true;
        priority = 10;
      };
      stylua = {
        enable = true;
        priority = 0;
      };

      actionlint = {
        enable = true;
        name = "actionlint";
        entry = "${pkgs.actionlint}/bin/actionlint";
        language = "system";
        files = "^\\.github/workflows/.*\\.ya?ml$";
        pass_filenames = false;
        priority = 10;
      };
      yamllint = {
        enable = true;
        name = "yamllint";
        entry = "${pkgs.yamllint}/bin/yamllint -c .yamllint.yml";
        language = "system";
        files = "\\.ya?ml$";
        priority = 10;
      };
      gitleaks = {
        enable = true;
        name = "gitleaks";
        # Wrapper ignores any filenames prek may append; gitleaks git takes
        # a single optional repo argument.
        entry = "${pkgs.writeShellScript "gitleaks-hook" ''
          exec ${pkgs.gitleaks}/bin/gitleaks git --pre-commit --redact --no-banner .
        ''}";
        language = "system";
        pass_filenames = false;
        always_run = true;
        stages = [ "pre-commit" ];
        priority = 10;
      };
      markdownlint = {
        enable = true;
        name = "markdownlint-cli2";
        entry = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2";
        language = "system";
        files = "\\.md$";
        priority = 10;
      };
      ruff = {
        enable = true;
        name = "ruff check";
        entry = "${pkgs.ruff}/bin/ruff check";
        language = "system";
        files = "\\.py$";
        priority = 10;
      };
      "ruff-format" = {
        enable = true;
        name = "ruff format";
        entry = "${pkgs.ruff}/bin/ruff format";
        language = "system";
        files = "\\.py$";
        priority = 0;
      };
      prettierd = {
        enable = true;
        name = "prettierd (markdown)";
        entry = "${pkgs.writeShellScript "prettierd-hook" ''
          set -euo pipefail
          for file in "$@"; do
            ${pkgs.prettierd}/bin/prettierd "$file" < "$file" > "$file.prettierd.tmp"
            mv "$file.prettierd.tmp" "$file"
          done
        ''}";
        language = "system";
        files = "\\.(md|mdx)$";
        priority = 0;
      };
      hadolint = {
        enable = true;
        name = "hadolint";
        entry = "${pkgs.hadolint}/bin/hadolint";
        language = "system";
        files = "(^|/)(Dockerfile|Containerfile)(\\..*)?$";
        priority = 10;
      };
      tflint = {
        enable = true;
        name = "tflint";
        entry = "${pkgs.tflint}/bin/tflint";
        language = "system";
        files = "\\.tf$";
        priority = 10;
      };
      "ansible-lint" = {
        enable = true;
        name = "ansible-lint";
        entry = "${pkgs.ansible-lint}/bin/ansible-lint";
        language = "system";
        files = "^(playbooks|roles)/.*\\.ya?ml$";
        priority = 10;
      };
      gersemi = {
        enable = true;
        name = "gersemi";
        entry = "${pkgs.gersemi}/bin/gersemi --check";
        language = "system";
        files = "(^|/)(CMakeLists\\.txt|.*\\.cmake)$";
        priority = 10;
      };

      nixconf-fast = {
        enable = true;
        name = "nixconf fast suite (flake, eval, shellcheck)";
        entry = "${pkgs.bash}/bin/bash ./scripts/test-all.sh flake eval shellcheck";
        language = "system";
        pass_filenames = false;
        always_run = true;
        stages = [ "pre-push" ];
        priority = 20;
      };

      nixconf-slow = {
        enable = true;
        name = "nixconf slow suite (disko, iso, vm)";
        entry = "${pkgs.bash}/bin/bash ./scripts/test-all.sh disko iso vm";
        language = "system";
        pass_filenames = false;
        always_run = true;
        stages = [ "pre-push" ];
        priority = 30;
      };

      nixconf-security = {
        enable = true;
        name = "nixconf security scan (trivy)";
        # FIDO2 resident-key handle is hardware-bound; see .gitleaks.toml.
        entry = "${pkgs.writeShellScript "trivy-hook" ''
          exec ${pkgs.trivy}/bin/trivy fs --scanners misconfig,secret --severity HIGH,CRITICAL --skip-files config/ssh/id_ed25519_sk_rk_alexis-perso --skip-db-update --exit-code 1 .
        ''}";
        language = "system";
        pass_filenames = false;
        always_run = true;
        stages = [ "pre-push" ];
        priority = 10;
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
    "repo:lint" = {
      description = "Lint GitHub workflows and YAML";
      exec = "actionlint && yamllint -c .yamllint.yml .github/workflows";
    };
    "repo:secrets" = {
      description = "Scan the working tree for secrets (gitleaks)";
      exec = "gitleaks dir . --no-banner --redact --config .gitleaks.toml";
    };
    "repo:security" = {
      description = "Trivy misconfiguration/secret scan (advisory)";
      # The FIDO2 resident-key handle is hardware-bound; see .gitleaks.toml.
      exec = "trivy fs --scanners misconfig,secret --severity HIGH,CRITICAL --skip-files config/ssh/id_ed25519_sk_rk_alexis-perso .";
    };
    "repo:stats" = {
      description = "Code statistics with tokei";
      exec = "tokei --sort code";
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
