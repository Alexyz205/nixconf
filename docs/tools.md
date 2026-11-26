# Tool inventory and purpose

This is the long-form map of what nixconf installs, why it is there, and which
command to reach for. It covers the shell, the dev environment, the Nix
tooling, the quality gates and the system helpers. Application-only desktop
packages (Steam, Discord, browsers, ArtCraft, Blender/FreeCAD) are listed at the
end; their configuration lives in their own feature modules.

## How tools are delivered

| Source                     | Scope                                                                                                        | Where                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------- |
| `modules/shell/*`          | interactive shell, terminal, file navigation                                                                 | NixOS + home-manager |
| `modules/dev/packages.nix` | package groups (`basic`, `nixTools`, `ciSecurity`, `nixPackaging`, `lsp`, `security`, `devTools`, `desktop`) | NixOS + home-manager |
| `modules/dev/*`            | git, lazygit, LazyVim, OpenCode, devenv, containers, GitLab, Bitwarden                                       | NixOS + home-manager |
| `modules/system/*`         | boot, disko, sops, SSH, YubiKey, monitoring, backup, Secure Boot, Wake-on-LAN                                | NixOS                |
| `devenv.nix`               | only this repo's build/test prerequisites                                                                    | repo dev shell       |
| per-project `devenv.nix`   | compilers, Terraform, kubectl, Helm, language runtimes                                                       | each project         |
| flake inputs               | `pkgs.opencode`, custom ArtCraft/niri packages                                                               | flake                |

The package groups are toggles:

```nix
modules.packages.ciSecurity = false;
modules.packages.nixPackaging = false;
```

`basic`, `nixTools`, `ciSecurity` and `nixPackaging` default to
true. `security`, `devTools` and `desktop` default to false and are switched on
by the host/profile tiers.

## Shell and terminal

| Tool              | Command / alias                                                  | Purpose                                                                                 |
| ----------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Zsh               | `zsh`                                                            | Interactive shell; vi keymap, autosuggestions, syntax highlighting, 100k shared history |
| Starship          | prompt                                                           | Fast cross-shell prompt with git/nix/language segments                                  |
| tmux              | `t`, `tmux`                                                      | Persistent sessions, panes, popups, agent status, smart window rename                   |
| zoxide            | `z`, `zi`                                                        | Frecency directory jumping (`z nixconf`)                                                |
| fzf               | `fzf`                                                            | Fuzzy finder used by tmux switchers, history pickers and LazyVim                        |
| eza               | `ls`, `ll`, `la`, `lt`, `lta`, `ldir`, `lm`, `lz`, `ldu`, `ldus` | `ls` replacement with git status, icons, tree                                           |
| bat               | `bat`                                                            | Syntax highlighter; pager for files, `git diff`, `gh`/`glab` (plain style, no grid)     |
| yazi              | `y`                                                              | Terminal file manager with previews, mounts, bulk rename                                |
| television (`tv`) | `tv`, `f`                                                        | Fuzzy picker for files, history, channels; powers `f`                                   |
| Ghostty           | `ghostty`                                                        | GPU terminal; tmux integration and config                                               |
| btop              | `btop`                                                           | Process/CPU/GPU/network dashboard (CUDA support on the workstation)                     |
| dust              | `dst`, `dsz`                                                     | Visual disk-usage tree (`du` replacement)                                               |
| duf               | `duf`                                                            | Readable filesystem/free-space overview (`df` replacement)                              |
| delta             | `delta`                                                          | Side-by-side syntax-highlighted git diffs                                               |
| lazygit           | `lg`                                                             | TUI for staging, commits, branches, rebase, worktrees                                   |
| cliphist          | `cliphist`                                                       | Wayland clipboard history                                                               |
| imv               | `imv`                                                            | Lightweight image viewer (Wayland/X11)                                                  |
| Moonlight         | `moonlight-qt`                                                   | Low-latency Sunshine client; RDP/Remmina stays as the console fallback                  |

## Core CLI

| Tool             | Purpose                                                              |
| ---------------- | -------------------------------------------------------------------- |
| `curl`, `wget`   | HTTP clients; installer downloads use temp files, never `curl \| sh` |
| `openssl`        | TLS/cert inspection and key tooling                                  |
| `ripgrep` (`rg`) | Fast recursive content search; preferred over `grep`                 |
| `fd`             | Fast file-name search; preferred over `find`                         |
| `jq`             | JSON querying/filtering                                              |
| `yq`             | YAML/JSON/XML/TOML querying and conversion                           |
| `tree-sitter`    | Parser CLI, grammar tests and syntax tooling                         |
| `fastfetch`      | Fast system information summary                                      |
| `wakeonlan`      | `wol <MAC>`, `wsw`, `wsa`: send a Wake-on-LAN magic packet           |
| `tokei`          | Code statistics by language (files, code, comments, blanks)          |
| `sd`             | Simpler, faster `sed` for find/replace with literal/regex            |
| `7z`, `tar`      | 7z (`p7zip`) for 7z/zip/rar; `tar` from the base system              |

## Nix ecosystem

| Tool                         | Purpose                                                                            | Alias                                                 |
| ---------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `nh`                         | Rebuild CLI for NixOS/Darwin/HM: build tree, package diff, `nom`, clean, search    | `nr`/`nrb`/`nrt`/`nro`, `dr`/`drb`, `hm`/`hmb`, `nhc` |
| `nvd`                        | Diff two NixOS/HM generations: packages, versions, sizes                           | `nd`                                                  |
| `nix-output-monitor` (`nom`) | Turns Nix build logs into a live dependency/build tree                             | `nb`                                                  |
| `nix-tree`                   | Interactive closure browser: sizes, dependencies, why a path exists                | —                                                     |
| `nix-index-database`         | Weekly nixpkgs index; powers `nix-locate`, `command-not-found` and wrapped `comma` | `, tool`                                              |
| `nixos-anywhere`             | Install NixOS over SSH (partition, kexec, install)                                 | —                                                     |
| `deploy-rs`                  | Push a built closure to a remote host with activation check and rollback           | `dep`, `depr`                                         |
| `nix-init`                   | Scaffold a new package derivation with hash prefetching and license detection      | —                                                     |
| `nurl`                       | Generate `fetchurl`/`fetchFromGitHub` calls and hashes from a URL                  | —                                                     |
| `nixpkgs-review`             | Build/test a nixpkgs PR locally and report failures                                | —                                                     |
| `disko`                      | Declarative partitioning/formatting used by the installer                          | —                                                     |
| `sops-nix`                   | Decrypt secrets at activation (see Security)                                       | `sec`                                                 |

Notes:

- `nh` handles sudo/elevation and shows a diff before activation. On profiles
  whose username contains a dot (`alexis.pigeon@...`) `hm` uses nh's
  auto-detection (`nh home switch $NIXCONF`) because nh treats dotted explicit
  keys as attribute paths.
- `nr`/`nrb`/`nrt`/`nro` mirror `nixos-rebuild switch/build/test/boot`; `dr`/
  `drb` mirror `darwin-rebuild`; `hm`/`hmb` mirror `home-manager`.
- `nc` is `nix flake check`, `nu` is `nix flake update`, `nl` is `nix flake
lock`, `ngc` is `nix store gc`, `ngo` is `nix store optimise`.
- `nix-index-database` replaces the old `programs.command-not-found` database;
  `nix-locate` and `,` use the same weekly index.

## CI, security and supply chain

| Tool         | Purpose                                                                               | Where used                     |
| ------------ | ------------------------------------------------------------------------------------- | ------------------------------ |
| `actionlint` | Lint GitHub Actions workflows (expressions, shellcheck on `run:` blocks, permissions) | pre-commit hook, `checks.lint` |
| `yamllint`   | YAML syntax/style checks                                                              | pre-commit hook, `checks.lint` |
| `gitleaks`   | Secret scanning of the working tree and staged diff                                   | pre-commit hook, `checks.lint` |
| `trivy`      | Misconfiguration and secret scanning; also vulnerabilities/images/IaC                 | pre-push hook, `repo:security` |

Configuration:

- `.yamllint.yml` is `extends: relaxed` with `line-length` disabled.
- `.gitleaks.toml` allowlists the FIDO2 resident-key handle at
  `config/ssh/id_ed25519_sk_rk_alexis-perso` (the private key never leaves the
  YubiKey) and the same filename string in `modules/system/yubikey.nix`.
- `repo:security` skips that one file; see the note at the end.

Commands:

```bash
actionlint
yamllint -c .yamllint.yml .github/workflows
gitleaks dir . --no-banner --redact --config .gitleaks.toml
trivy fs --scanners misconfig,secret --severity HIGH,CRITICAL .
```

## LSPs, formatters and linters

These are installed globally so LazyVim/OpenCode and any editor find them on
`PATH`; per-project `devenv.nix` can override versions.

| Language  | LSP                                                             | Formatter   | Linter              |
| --------- | --------------------------------------------------------------- | ----------- | ------------------- |
| Nix       | `nil`                                                           | `nixfmt`    | `statix`, `deadnix` |
| Shell     | `bash-language-server`                                          | `shfmt`     | `shellcheck`        |
| Python    | `basedpyright`                                                  | `ruff`      | `ruff`              |
| Lua       | `lua-language-server`                                           | `stylua`    | `luacheck`          |
| Markdown  | `marksman`                                                      | `prettierd` | `markdownlint-cli2` |
| YAML      | `yaml-language-server`                                          | —           | `yamllint`          |
| JSON      | `vscode-langservers-extracted`                                  | —           | —                   |
| TOML      | `taplo`                                                         | `taplo`     | —                   |
| Terraform | `terraform-ls`                                                  | —           | `tflint`            |
| C/C++     | `clangd` (`clang-tools`)                                        | —           | —                   |
| CMake     | `cmake-language-server`                                         | `gersemi`   | —                   |
| Docker    | `dockerfile-language-server`, `docker-compose-language-service` | —           | `hadolint`          |
| Ansible   | `ansible-language-server`                                       | —           | `ansible-lint`      |
| Helm      | `helm-ls`                                                       | —           | —                   |

`devenv.nix` in this repo installs only the test prerequisites (`disko`,
`shellcheck`); the formatters, LSPs and linters above come from the global
`packages.lsp`/`ciSecurity` groups, and the git hooks bring their own tools.

## Secrets and identity

| Tool                            | Purpose                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------------ |
| `sops`                          | Edit/decrypt encrypted YAML (`secrets/secrets.yaml`, `secrets/corp.yaml`)            |
| `age`                           | Modern encryption used by sops; YubiKey plugin for hardware identity                 |
| `age-plugin-yubikey`            | Age identity backed by the YubiKey                                                   |
| `gnupg`                         | GPG keys/signing where needed                                                        |
| `restic` / `restic-nas`         | Encrypted deduplicated backups; `restic-nas` sets the repo and password (`rs` alias) |
| `ssh`, `ssh-keygen`             | SSH keys, resident FIDO2 keys, initrd/remote access                                  |
| `pamu2fcfg`, `pam_u2f`, `ykman` | FIDO2 enrollment, sudo/login/U2F mapping, YubiKey management                         |
| `bitwarden` (`bw` + desktop)    | Password manager / CLI                                                               |
| `gh`, `glab`                    | GitHub/GitLab CLIs; credentials come from interactive login, not sops                |

Rules: never print or commit plaintext secrets; `sec` edits
`secrets/secrets.yaml` and `secc` edits `secrets/corp.yaml`; decryption needs
the YubiKey except on the workstation (software age key). `gh auth login` and
`glab auth login` store their token in the OS keyring (or their own 0600 config
when no keyring runs); the repo only wires the non-secret credential helpers.
Git identity follows the directory tree: `~/repos/work/` is work,
`~/repos/personal/` is personal.

## Containers, infrastructure and AI

| Tool                  | Purpose                                                                        |
| --------------------- | ------------------------------------------------------------------------------ |
| `podman`              | Rootless container runtime, docker-compatible socket                           |
| `docker`              | Podman's docker-compatible CLI wrapper                                         |
| `lazydocker` (`ld`)   | TUI for containers, logs, stats, pruning                                       |
| `devpod` (`ds`, `du`) | Devcontainer workspaces over SSH                                               |
| `devenv`              | Per-repo declarative dev environments; auto-activates on `cd`                  |
| `uv`                  | Fast Python installer/resolver (with OpenCode MCP / personal profiles)         |
| `opencode`            | AI coding agent; config in `config/opencode`, MCP servers                      |
| `nvim` (LazyVim)      | Editor with the LSP/formatter set above, gitlab.nvim, yazi.nvim, opencode.nvim |

Rootless podman loads `storage.rootless.conf.d/10-nixos-rootless.conf` with
`overlay.ignore_chown_errors = "true"`. Layers carrying UIDs/GIDs no subuid range
can map (corp images built from AD/idmapped trees, e.g. `dxyzsdk`) then unpack
with those IDs squashed to the calling user instead of failing the pull with
"potentially insufficient UIDs or GIDs". Rootful is untouched.

## System operations

| Feature        | Tools                                                   | Purpose                                                                      |
| -------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Monitoring     | `node_exporter`, `smartd`, btrfs scrub, journald limits | Metrics on `127.0.0.1:9100`, disk health, silent-corruption detection        |
| Backup         | `restic` service, `restic-nas`                          | Daily encrypted/pruned snapshots; enabled on workstation and headless-worker |
| Secure Boot    | `lanzaboote`, `sbctl`                                   | Signed UKIs; opt-in after key enrollment                                     |
| Wake-on-LAN    | `ethtool`, `wakeonlan`                                  | Magic-packet wake (`wol`, `wsw`, `wsa`); hibernate/TPM2 on rnsw              |
| Remote desktop | `moonlight-qt`, `remmina`, `freerdp`                    | Sunshine/Moonlight for low latency; RDP console fallback                     |
| Work SSH       | `sync-work-ssh`                                         | Fleet aliases from infra_management into ~/.ssh/config.d/work                |
| VPN            | `gpclient`, `gpvpn`                                     | GlobalProtect SSO via the external browser; `pkexec` sets up the tunnel      |
| Networking     | NetworkManager/systemd-networkd, `nmcli`, `resolvectl`  | Wired/Wi-Fi, DNS, firewall                                                   |
| Disks          | `disko`, `lsblk`, `udisksctl`, `mount`                  | Declarative layout and inspection                                            |
| Remote deploy  | `deploy-rs`, `nixos-anywhere`                           | Push closures; install over SSH                                              |

## Repo quality gates

Pre-commit (fast, staged):

- `nixfmt`, `shfmt`, `statix`, `deadnix`, `shellcheck`, `luacheck`, `stylua`
- `markdownlint-cli2`, `ruff check`, `ruff format`
- `actionlint`, `yamllint`, `gitleaks`

Pre-push:

- `trivy` (misconfig + secrets)
- fast suite (`nix flake check`, dry-run eval, shellcheck)
- slow suite (`disko`, `iso`, `vm`)

Flake checks:

- `checks.format` — nixfmt/shfmt/shellcheck/statix/deadnix
- `checks.lint` — actionlint/yamllint/gitleaks
- `checks.server-boot` — QEMU boot test (sshd, fail2ban, nix)

LazyVim uses the same set:

- conform: `nixfmt`, `shfmt`, `stylua`, `ruff_format`, `prettierd` +
  `markdownlint-cli2`, `gersemi`
- nvim-lint: `statix` + `deadnix`, `shellcheck`, `yamllint`, `actionlint`
  (workflow filetype), `ansible_lint`, `luacheck`, `markdownlint-cli2`,
  `ruff`, `hadolint`, `tflint`, `terraform_validate`, `gersemi`
- `<leader>xg` runs `gitleaks`, `<leader>xt` runs `trivy` in a terminal split

Shared configuration: `.yamllint.yml`, `.markdownlint-cli2.yaml`,
`.gitleaks.toml` and `ruff.toml` are used by both the hooks and LazyVim.

Tasks:

```bash
devenv tasks run repo:fmt
devenv tasks run repo:lint
devenv tasks run repo:secrets
devenv tasks run repo:security
devenv tasks run repo:stats
devenv tasks run test:all
```

## Which tool when

| Need                      | Use                                                      |
| ------------------------- | -------------------------------------------------------- |
| Find text                 | `rg`; add `-t nix` for file types                        |
| Find files                | `fd`; `fzf`/`tv` interactively                           |
| Navigate                  | `z` (frecency), `y` (file manager), `tv`                 |
| Git                       | `g`/`gs`/`gc`/`gp`/`gl`, `lg` for TUI, `delta` for diffs |
| Nix rebuild               | `nr` (switch), `nrb` (build), `nrt` (test), `nro` (boot) |
| See what a switch changes | `nd`/`nvd diff`, `nh` output                             |
| Debug a closure           | `nix-tree`                                               |
| Run a missing tool        | `, tool`                                                 |
| Find a package            | `nix-locate`, `nh search`, `nix search`                  |
| Packaging                 | `nix-init`, `nurl`, `nixpkgs-review`                     |
| Code stats                | `tokei`                                                  |
| Secret scan               | `gitleaks`, `trivy fs --scanners secret`                 |
| Workflow lint             | `actionlint`                                             |
| YAML lint                 | `yamllint`                                               |
| Infra/image scan          | `trivy`                                                  |
| Remote install/deploy     | `nixos-anywhere`, `dep`/`depr`                           |

## Security note

The repository tracks `config/ssh/id_ed25519_sk_rk_alexis-perso`: an OpenSSH
FIDO2 **resident-key handle**, not an extractable private key. The private key
stays on the YubiKey, but the handle is still required at `~/.ssh/` to use the
resident credential. Gitleaks and Trivy both classify the file as a private key,
so `.gitleaks.toml` allowlists it and `repo:security` skips it with
`--skip-files`.

If you ever want to stop tracking it, move the handle out of the repo, provision
it per machine (or through sops), and remove the allowlist/skip. Until then the
allowlist is deliberate and documented here.

## Desktop applications (not dev tools)

The desktop modules install Chromium, Claude, Discord, Steam/Heroic, Prism,
Moonlight (moonshine), Thunderbird, YouTube Music, GitLab tooling, imv,
ArtCraft (Photo/Light/PDF/Film/Word/Grid/Cad/Deck/SoundCraft), Blender and
FreeCAD. They are enabled by the `desktop` tier and the `personalExtra`/`workExtra`
profiles; see their modules for details. `vlc` is Linux-only; macOS gets a
smaller subset.
