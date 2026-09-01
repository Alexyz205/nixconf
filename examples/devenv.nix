# devenv.nix — full reference template for new repositories.
#
# Copy this file into a new repo root as `devenv.nix` (keep `devenv.yaml`
# alongside) and UNCOMMENT only the tools that repo actually needs. Every
# entry is grouped by concern so you can pick what you want.
#
# Design rules (from the nixconf README):
#   - One tool per job, no duplicates. LazyVim's `extras.lang.*` are lazy
#     config only (mason is disabled); the binaries below are what LazyVim
#     and opencode's built-in LSP pick up from $PATH.
#   - Anything not already global on NixOS (compilers, language-specific
#     toolchains) belongs here in the repo's devenv.nix.
#   - Test prerequisites for the repo's CI/test script live here too.
#
# LSPs / formatters table (copy the row you need):
#   language | LSP                          | formatter      | linter
#   nix      | nil                          | nixfmt         | statix
#   python   | basedpyright                 | ruff           | ruff
#   shell    | bash-language-server         | shfmt          | shellcheck
#   lua      | lua-language-server          | stylua         | luacheck
#   markdown | marksman                     | prettierd      | markdownlint-cli2
#   json     | vscode-json-languageserver   | —              | (in LSP)
#   yaml     | yaml-language-server         | —              | (in LSP)
#   toml     | taplo                        | —              | —
#   terraform| terraform-ls                 | terraform fmt  | tflint
#   docker   | dockerfile-language-server-* | —              | hadolint
#   cmake    | cmake-language-server        | gersemi        | gersemi --check
#   c/cpp    | clangd                       | clang-format   | clang-tidy
#   arduino  | clangd (via c/cpp)           | clang-format   | clang-tidy
{ pkgs, ... }: {
  name = "my-repo";

  env = {
    TERM = "screen-256color";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  # ---------------------------------------------------------------------------
  # packages — LSPs, formatters, linters, test prerequisites
  # ---------------------------------------------------------------------------
  # Devenv also installs LSPs via `languages.*` batteries below; prefer the
  # battery where one exists, and use `packages` for standalone tools
  # (formatters/linters that have no battery, plus CI/test prerequisites).
  packages = with pkgs; [
    # --- test / CI prerequisites ---
    # disko          # disk layout testing (test-all.sh disko)
    # shellcheck     # bash linter (test-all.sh shellcheck)

    # --- secrets (sops + YubiKey age) ---
    # sops
    # age-plugin-yubikey

    # --- markdown: LSP marksman, formatter prettierd, linter markdownlint-cli2
    # marksman
    # prettierd
    # markdownlint-cli2

    # --- yaml: LSP yaml-language-server
    # yaml-language-server

    # --- json: LSP vscode-json-languageserver
    # vscode-json-languageserver

    # --- toml: LSP taplo
    # taplo

    # --- nix: formatter nixfmt (LSP nil + linter statix via languages.nix)
    # nixfmt

    # --- python: linter + formatter ruff (LSP basedpyright via languages.python)
    # ruff

    # --- lua: formatter stylua, linter luacheck (LSP via languages.lua)
    # stylua
    # luaPackages.luacheck

    # --- terraform: linter tflint (LSP + fmt via languages.terraform)
    # tflint

    # --- docker: LSPs + linter
    # dockerfile-language-server-nodejs
    # docker-compose-language-service
    # hadolint

    # --- cmake: LSP + formatter/linter
    # cmake-language-server
    # gersemi

    # --- arduino: build tool (LSP clangd + fmt/lint via languages.c/cplusplus)
    # arduino-cli
  ];

  # ---------------------------------------------------------------------------
  # languages — compiler/runtime + matching LSP battery
  # ---------------------------------------------------------------------------
  languages = {
    # --- nix: LSP nil, linter statix + deadnix (formatter nixfmt via packages)
    # nix = {
    #   enable = true;
    #   lsp.package = pkgs.nil;
    # };

    # --- python: LSP basedpyright (linter + formatter ruff via packages)
    # python = {
    #   enable = true;
    #   lsp.package = pkgs.basedpyright;
    # };

    # --- shell / bash: LSP bash-language-server, linter shellcheck, formatter shfmt
    # shell.enable = true;

    # --- c: LSP clangd, formatter clang-format, linter clang-tidy (clang-tools)
    # c = {
    #   enable = true;
    #   lsp.enable = false;
    # };

    # --- c++: LSP clangd, formatter clang-format, linter clang-tidy; adds cmake + clang
    # cplusplus = {
    #   enable = true;
    #   lsp.enable = false;
    # };

    # --- lua: LSP lua-language-server (formatter stylua + linter luacheck via packages)
    # lua.enable = true;

    # --- terraform: LSP terraform-ls, formatter terraform fmt/validate (linter tflint via packages)
    # terraform.enable = true;

    # --- ansible: LSP ansible-language-server, linter ansible-lint
    # ansible.enable = true;
  };

  # ---------------------------------------------------------------------------
  # treefmt — repo-wide formatters (nixfmt, shfmt, prettierd, ...). Same tools
  # LazyVim uses. Run `treefmt` in `devenv shell` to apply.
  # ---------------------------------------------------------------------------
  # treefmt = {
  #   enable = true;
  #   config = {
  #     programs = {
  #       nixfmt.enable = true;
  #       shfmt.enable = true;
  #     };
  #     # prettierd reads stdin and takes the filename as a positional arg, so
  #     # wrap it to write in place (treefmt's contract).
  #     settings.formatter.prettierd = {
  #       command = "${pkgs.bash}/bin/bash";
  #       options = [
  #         "-euc"
  #         ''
  #           for file in "$@"; do
  #             ${pkgs.prettierd}/bin/prettierd "$file" < "$file" > "$file.prettierd.tmp" || exit 1
  #             mv "$file.prettierd.tmp" "$file"
  #           done
  #         ''
  #         "--"
  #       ];
  #       includes = [ "*.md" "*.mdx" ];
  #       excludes = [ ".git/*" ".devenv/*" ];
  #     };
  #   };
  # };

  # ---------------------------------------------------------------------------
  # tasks — project commands via `devenv tasks run <name>`
  # (also reachable through the tv `devenv-tasks` channel)
  # ---------------------------------------------------------------------------
  tasks = {
    # "example:build" = {
    #   description = "Build example";
    #   exec = "echo "EXAMPLE!!!;
    # };
  };

  # ---------------------------------------------------------------------------
  # devcontainer — generates .devcontainer/devcontainer.json so the repo opens
  # in a dev container. Two images to choose from:
  # ---------------------------------------------------------------------------
  # devcontainer = {
  #   enable = true;
  #   settings = {
  #     image = "mcr.microsoft.com/devcontainers/base:ubuntu-24.04";
  #     overrideCommand = true;
  #     features."ghcr.io/devcontainers/features/nix:1" = {
  #       extraNixConfig = "experimental-features = nix-command flakes";
  #       packages = "devenv";
  #     };
  #     # settings.updateContentCommand = "devenv test";   # default
  #     # settings.customizations.vscode.extensions = [ "mkhl.direnv" ]; # default
  #   };
  # };

  # ---------------------------------------------------------------------------
  # containers — extra devenv containers for `devenv container` / CI
  # (see https://devenv.sh/containers/)
  # ---------------------------------------------------------------------------
  # containers."test" = {
  #   startupCommand = "${pkgs.nix}/bin/nix flake check";
  # };
}
