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
}
