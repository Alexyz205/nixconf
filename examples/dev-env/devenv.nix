# Default per-project dev environment (devenv).
# Copy this file to the root of a new repo, e.g. `cp examples/dev-env/devenv.nix $REPO/`.
#
# The mental model (see modules/shell/lazyvim.nix):
#   - Global NixOS (nixconf) ships LSPs for the 5 lazyvim extras: json, markdown,
#     python, toml, yaml.
#   - Anything extra (C++, Rust, Go, ...) or language SPECIFIC VERSIONS belongs here,
#     per repo. `devenv shell` puts it on $PATH and LazyVim auto-detects the LSP.
#   - TODO stubs below are safe no-ops you can edit per project.
{pkgs, ...}: {
  # Raw nixpkgs packages installed into the dev environment.
  packages = with pkgs; [
    # Static tools (same role as in ~/.config/shell aliases)
    neovim
    git
    lazygit
    gh
    ripgrep
    fd

    # LSP/formatters already global in lazyvim.nix extraPackages — keep here so the
    # dev shell is self-contained for anyone cloning without nixconf:
    marksman
    yaml-language-server
    vscode-json-languageserver
    basedpyright
    taplo
    ruff
    prettierd
    markdownlint-cli

    # TODO: LANGUAGE-SPECIFIC LSPs for THIS repo (e.g. C++ → clang-tools for clangd).
    # They are NOT global on NixOS — add them per repo, or use `languages.*` below.
  ];

  # Built-in language "batteries" — real compiler/runtime versions, plus the matching LSP.
  # Enable ONLY what this repo actually uses; leave the rest off to keep the env fast.
  languages = {
    # nix → nixfmt, nix-language-server (handy for editing devenv.nix itself)
    nix.enable = true;

    # python → brings python + pip + basedpyright already global from lazyvim
    python.enable = true;

    # node/npm/typescript toolchain for JS/TS repos
    # (uncomment what your repo needs)
    # node.enable = true;
    # typescript.enable = true;

    # C / C++ → clangd, lldb, clang-tools, cmake
    # c.enable = true;
    # cpp.enable = true;

    # Rust → rustc, cargo, rust-analyzer
    # rust.enable = true;

    # Go → go, go envs, gopls LSP
    # go.enable = true;
  };

  # Env variables exported into the dev shell (matches the devcontainer.json).
  env = {
    TERM = "screen-256color";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  # Regenerate .devcontainer/devcontainer.json from this devenv.nix on every
  # `devenv shell`/`devenv test`. Uses the official devenv base image, so
  # `devpod up .` gives you the exact same tools as the local dev shell.
  devcontainer.enable = true;

  # Runs when you enter `devenv shell` / `devenv up`.
  enterShell = ''
    echo "Dev shell ready — run 'devenv tasks list' to see available tasks"
  '';

  # Project tasks: runnable via `devenv tasks run <name>` (or the TV channel
  # `devenv-tasks`). Edit `exec` to your real commands. Task names must use
  # `namespace:name` format (devenv >= 2.0).
  tasks = {
    "project:dev" = {
      description = "Start the dev server";
      exec = "echo 'TODO: define your dev server'";
    };
    "project:build" = {
      description = "Build the project";
      exec = "echo 'TODO: define your build command'";
    };
    "project:test" = {
      description = "Run the test suite";
      exec = "echo 'TODO: define your test command'";
    };
    "project:lint" = {
      description = "Lint the codebase";
      exec = "echo 'TODO: define your lint command'";
    };
    "project:fmt" = {
      description = "Format the codebase";
      exec = "echo 'TODO: define your format command'";
    };
  };
}