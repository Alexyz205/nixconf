---
name: toolbox
description: Inventory of nixconf CLI tools, aliases, app binaries, and MCP servers so OpenCode can choose the right command
license: MIT
compatibility: opencode
metadata:
  audience: devops
  workflow: tooling
---

# Toolbox

The shell is the primary interface to every tool. Prefer the dedicated command
over a raw equivalent, confirm availability with `command -v <tool>`, and never
run destructive/remote-changing commands without asking.

## Nix / repo

- `nix`, `nixos-rebuild`, `home-manager`, `nixfmt`, `statix`, `deadnix`,
  `treefmt`, `shellcheck`, `shfmt`, `stylua`, `luacheck`, `devenv`.
- Aliases: `nc` (flake check), `nr`/`nrb`/`nrt` (NixOS switch/build/test),
  `dr`/`drb`/`drc` (darwin), `hm`/`hmb`/`hmc` (standalone HM), `nu` (update),
  `nl` (lock), `ngc` (GC), `ngo` (optimise).
- Repo: `$NIXCONF`; `nf` jumps there. `devenv` auto-activates in repos with a
  `devenv.nix`; per-repo toolchains (Terraform, kubectl, language compilers)
  live there and take precedence on `$PATH`.

## Terminal / files

- `zsh`, `starship`, `tmux` (`t`), `zoxide` (`z`, `zi`), `fzf`.
- `eza` (`ls`, `ll`, `la`, `lt`, `lta`, `ldir`, `lm`, `lz`, `ldu`, `ldus`).
- `bat`, `less`, `tree-sitter`, `fastfetch`.
- `ripgrep` (`rg`), `fd`, `jq`, `yq`.
- `dust` (`dst`, `dsz`), `duf`, `btop`.
- `yazi` (`y`), `tv` (`f`, `Ctrl+T` smart autocomplete, `Ctrl+R` history).
- `cliphist`, `wl-copy`/`wl-paste` (Wayland), `swayimg` (image opener).

## Git / forge

- `git` (aliases: `g`, `ga`, `gc`, `gcm`, `gco`, `gd`, `gl`, `gp`, `gP`, `gs`;
  `gh:`/`gl:` URL prefixes), `delta`, `lazygit` (`lg`).
- `gh` (GitHub CLI), `glab` (GitLab CLI). Remote-changing operations are manual
  per `AGENTS.md`: do not push, comment, approve, or merge.
- `gitlab.nvim` and the LazyVim dashboard use the per-host GitLab PATs.

## Containers / infra

- `podman` (docker-compatible), `docker`, `docker-compose`, `lazydocker` (`ld`),
  `devpod` (`ds` ssh, `du` up).
- `kubectl`, `helm`, `terraform`, `ansible`, `tflint` etc. are usually provided
  by each repo's `devenv.nix`; check `command -v` before using. Global
  `terraform-ls`, `tflint`, `ansible-lint`, `helm-ls` are language servers only.
- `systemctl`, `journalctl`, `nmcli`, `lsblk`, `udisksctl`, `mount`, `disko`.

## Secrets / identity

- `sops`, `age`, `age-plugin-yubikey`, `gpg`, `ssh`, `ssh-keygen`.
- `sec` edits `secrets/secrets.yaml`; `sece` edits `secrets/env.yaml`.
- Never print or commit secrets; do not read plaintext identities.

## Editing / AI

- `nvim` (LazyVim, alias `v`) with the configured LSPs/formatters.
- `opencode` (OpenCode), its agents/skills/plugins, and MCP servers:
  `context7`, `gh_grep`, `blender`, `freecad` (the latter two only where the
  apps are enabled).
- `opencode` formatters run `nixfmt`, `shfmt`, `ruff`, `clang-format`, etc.
  after edits when available.

## ArtCraft / CAD

- `photocraft`, `lightcraft`, `pdfcraft`, `filmcraft`, `wordcraft`,
  `gridcraft`, `cadcraft`, `deckcraft`, `soundcraft`.
- `blender` (3D-print extensions + MCP) and `freecad` (3D-print addons + MCP).
- Load the `artcraft`, `blender`, or `freecad` skill for detailed workflows.

## Rules

- Prefer `rg`, `fd`, `jq`, `yq`, `eza`, `bat` over `grep`, `find`, `cat`.
- Use `tv`/`yazi`/`zoxide` for interactive navigation; use `rg`/`fd` in scripts.
- Ask before `rm`, `git add/commit/push`, `gh`/`glab` writes, `systemctl` state
  changes, `podman/docker` deletes, `kubectl` deletes, `terraform destroy`.
- Report when a tool is missing instead of silently falling back to a weaker
  substitute; add it to the repo's `devenv.nix` or the relevant nixconf group.
