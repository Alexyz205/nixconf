# dev-env example

Template for a new repo's developer environment. Copy these into a project root:

```bash
cp -r examples/dev-env/. $REPO/
```

Both files are independent — use one or both.

## `.devcontainer/devcontainer.json` — devpod / Dev Containers

Used by `devpod up .` (`du` alias) or VS Code Dev Containers. Declares:

- `image` — the container base (Ubuntu here). Swap for your language image, e.g.
  `mcr.microsoft.com/devcontainers/cpp:ubuntu` for C++, or a `Dockerfile` instead.
- `remoteEnv` — env vars passed to the IDE/SSH server inside the container.
- `containerEnv` — env vars set for processes inside the container.

Note: JSON has no comments, so anything else goes in this README.

## `devenv.nix` — local Nix dev shell

Used with `devenv up` / `devenv shell` / `devenv tasks run <task>`. Sections:

| Section      | Purpose                                    | Edit to                              |
| ------------ | ------------------------------------------ | ------------------------------------ |
| `packages`   | Raw nixpkgs packages in the env            | Add LSPs like `clang-tools`, `gopls` |
| `languages`  | Compiler/runtime + LSP batteries           | Enable `cpp`, `rust`, `go`, ...      |
| `env`        | Shell env vars (mirrors devcontainer.json) | Add `DATABASE_URL`, etc.             |
| `enterShell` | Runs on entering the shell                 | Print hints, run setup scripts       |
| `tasks`      | Repo commands via `devenv tasks run`       | Your real `dev`/`test`/`build`       |

### Mental model (see modules/shell/lazyvim.nix)

- Global NixOS LSPs: json, markdown, python, toml, yaml (the 5 lazyvim extras).
- Everything else is **per repo** via devenv — LazyVim picks servers from `$PATH`,
  so a C++ repo just needs `languages.cpp.enable = true` and `clangd` is found.

### Common additions

```nix
# C / C++
cpp.enable = true;   # clangd, lldb, clang-tools, cmake

# Rust
rust.enable = true;  # rustc, cargo, rust-analyzer

# Go
go.enable = true;    # go, gopls
```
