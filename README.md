# nixconf

Dendritic NixOS configuration built on flake-parts + import-tree + home-manager.
One repo drives every machine and environment you own: NixOS desktops and
servers, nix-darwin laptops, Proxmox VMs, a USB installer ISO, and standalone
home-manager profiles — all sharing the same feature modules.

## Architecture

The flake entry point (`flake.nix`) is tiny: it delegates everything to
flake-parts, and import-tree recursively loads every `*.nix` file under
`modules/` as a flake-parts module. Feature modules declare a NixOS side
(`flake.modules.nixos.<feature>`) and, where relevant, a home-manager side
(`flake.modules.homeManager.<feature>`), and each host mixes them via a
`features` list.

The core design principle is **self-contained feature modules**. Each tool
module owns its `enable` option, the packages it installs, and its zsh aliases.
Enabling a feature is one line (`modules.<feature>.enable = true`) and the
aliases come along. The `shell` module is the exception: it centralizes the
environment and the platform-specific rebuild aliases, gated per platform (see
[Commands](#commands)).

Hosts are composed from **feature tiers** rather than hand-listed modules: a
`base` tier (terminal tooling) is the default for every host, `server` adds
storage/secrets/containers, and `desktop` layers the GUI stack on top. Adding a
new machine is mostly choosing a tier and a few extras.

```text
flake.nix               # Entry point: flake-parts + import-tree
devenv.nix / devenv.yaml# Dev environment for this repo (see "Dev environment")
modules/
├── flake/              # options.nix (option types), nixos.nix (feature tiers), home-manager.nix (standalone configs)
├── hosts/              # One file per machine / image
├── system/             # boot, disko, network, nextcloud, nix, podman, sops, security, ssh, users, yubikey
├── shell/              # shell, starship, tmux, zoxide, eza, bat, btop, yazi, ghostty
├── desktop/            # niri, brave, claude, discord, steam, youtube-music, ...
└── dev/                # devenv, git, gitlab, lazygit, lazyvim, opencode, containers, ...
config/                 # Dotfiles & static assets referenced from feature modules
scripts/                # install.sh, test-all.sh, build-iso.sh
secrets/                # sops-encrypted secrets
```

The `modules/` subdirectories are organizational only — import-tree loads every
file regardless of location, so a feature can be added or moved without touching
the flake.

## Install scripts

Two standalone bootstrap scripts let anyone get the nixconf tooling without
installing a full host config or home-manager.

### `scripts/install.sh` — container / server bootstrap

Bootstrap a container or server with the full nixconf dotfiles (zsh, starship,
tmux, tools, aliases) from a standalone home-manager profile:

```bash
./scripts/install.sh container   # default: single-user Nix in a container/devpod
./scripts/install.sh server      # multi-user Nix (daemon) on a server/image
```

It installs Nix via the official installer (downloaded to a temp file — never
`curl | sh`), clones this repo, and activates the matching home-manager config
(`<user>@container` for containers, `alexis@server` for servers). The container
user is picked at runtime from `id -un` (`root@container` or `vscode@container`).

## Hosts

| Host              | Platform       | Type    | Key Features                                                                            |
| ----------------- | -------------- | ------- | --------------------------------------------------------------------------------------- |
| `macbook`         | aarch64-darwin | Laptop  | nix-darwin, Homebrew, Ghostty, Nextcloud (rclone)                                       |
| `workstation`     | x86_64-linux   | Desktop | Niri WM, Catppuccin (stylix), greetd, pipewire, YubiKey LUKS + sudo, Nextcloud (davfs2) |
| `headless-worker` | x86_64-linux   | Server  | systemd-networkd, btrfs disko, SSH via YubiKey key, Nextcloud (davfs2), weekly GC       |
| `proxmox-vm`      | x86_64-linux   | VM      | cloud-init, Proxmox image, qemu-guest, minimal                                          |
| `installer-iso`   | x86_64-linux   | USB ISO | Guided installer script with YubiKey auth                                               |

Standalone home-manager profiles (`flake.homeConfigurations`):

| Config                        | Username      | Platform       | Notes                                |
| ----------------------------- | ------------- | -------------- | ------------------------------------ |
| `alexis@macos`                | alexis        | aarch64-darwin | macOS profile                        |
| `alexis@linux`                | alexis        | x86_64-linux   | Linux profile                        |
| `alexis.pigeon@RNSL-APIGEON5` | alexis.pigeon | x86_64-linux   | Professional machine profile         |
| `alexis@server`               | alexis        | x86_64-linux   | Headless server (terminal-only)      |
| `root@container`              | root          | x86_64-linux   | Container profile (root)             |
| `vscode@container`            | vscode        | x86_64-linux   | Devcontainer profile (non-root user) |

Hosts are referenced by their flake attribute: `nixosConfigurations.workstation`,
`darwinConfigurations.macbook`, `homeConfigurations."alexis@linux"`, etc.

## Commands

Rebuild aliases are zsh aliases defined by the `shell` module and gated per
platform: NixOS hosts get the `nixos-rebuild` set, nix-darwin the
`darwin-rebuild` set, and standalone home-manager profiles the `home-manager`
set. The `nix` flake aliases exist on every platform. All aliases use the
`$NIXCONF` env var.

The most common ones:

```bash
nc   # nix flake check $NIXCONF          (every platform)
nr   # sudo nixos-rebuild switch --flake $NIXCONF   (NixOS)
dr   # sudo darwin-rebuild switch --flake $NIXCONF  (nix-darwin)
hm   # home-manager switch --flake $NIXCONF         (standalone home-manager)
```

Each family has build/test variants (`nrb`/`nrt`, `drb`/`drc`, `hmb`/`hmc`) plus
flake helpers (`nu` update, `nl` lock, `ngc` gc, `ngo` optimise). The complete
set lives in `modules/shell/shell.nix` — the README doesn't duplicate it.

Beyond the rebuild aliases, every tool module ships its own aliases alongside
its `enable` flag and packages (e.g. `eza` provides `ls`/`ll`/`la`, `git`
provides `g`/`gs`/`gc`/…, `lazygit` provides `lg`, `tmux` provides `t`). The
full per-module alias list is defined in each module under `modules/`.

## Test suite

`scripts/test-all.sh` validates the whole repo:

```bash
./scripts/test-all.sh           # run all tests
./scripts/test-all.sh eval      # just evaluate configs
./scripts/test-all.sh -l        # list available tests
```

| Test         | What it does                                     |
| ------------ | ------------------------------------------------ |
| `flake`      | `nix flake check` (all configs, options, checks) |
| `eval`       | Dry-run builds every NixOS + home-manager config |
| `disko`      | Disko dry-run for workstation & headless-worker  |
| `iso`        | Builds the `installer-iso` ISO image             |
| `vm`         | Builds the Proxmox VM image (`.#proxmox-vm`)     |
| `shellcheck` | Lints `scripts/*.sh`                             |

If `disko` or `shellcheck` aren't on `$PATH`, the script re-enters itself via
`devenv shell` so the tools are always available.

## Dev environment (devenv)

Devenv provides the shell the test suite needs and is the template for any new
repository you start.

### For this repo

`devenv.nix` at the root is kept to **only what this repo needs** — the test
prerequisites for `scripts/test-all.sh` and the language batteries for the
languages this repo is written in. Global tooling (secrets, LSPs/formatters/
linters) is installed by the `packages` module's groups instead, so nothing is
duplicated between the dev environment and the system.

The dev shell itself is optional — in day-to-day use the tools are already on
`$PATH` via devenv **auto-activation** (see below) and the dev container. Drop
into it manually only when you need a one-off:

```bash
devenv shell        # drop into the dev shell
devenv up           # run services / stay resident (here: no services)
```

`devenv.nix` also generates the dev container: `devenv` writes
`.devcontainer/devcontainer.json` (Ubuntu 24.04 base, direnv extension) so the
repo opens with the same tooling in VS Code/Zed, and `devenv container`
builds a `test` container that runs `nix flake check` for CI. Anything beyond
this repo's own needs is documented in the reference template at
`examples/devenv.nix`.

On NixOS hosts the `modules.dev.devenv` feature is enabled, which installs
`devenv` system-wide and adds a zsh hook so devenv **auto-activates** when
you `cd` into a repo that has its own `devenv.nix`. (Same behavior is provided
for standalone home-manager profiles.)

### For a new / other project

The full reference template lives at `examples/devenv.nix` — copy it into any
new repo root and UNCOMMENT only the tools that repo actually needs:

```bash
cp $NIXCONF/examples/devenv.nix $REPO/devenv.nix
devenv shell        # now enter that repo's dev environment
```

The mental model: LazyVim itself (the `lazyvim` feature) only provides
neovim + config + aliases — **LSPs and formatters live in each repo's
`devenv.nix`**, so they're available from `$PATH` inside the activated dev shell.
The template shows how to wire `packages` (standalone LSPs/formatters/linters),
`languages` (compiler/runtime + matching LSP batteries), `env`, `treefmt`
(repo-wide formatters), `tasks` (project commands), `devcontainer`, and
`containers` (CI). The full per-language LSP/formatter/linter table lives in the
template — it's not duplicated here.

The rule is **one tool per job, no duplicates**. Anything that isn't already
global on NixOS (C++/Rust/Go toolchains, language-specific compiler versions)
belongs in the repo's `devenv.nix`, not in nixconf. The LazyVim LSPs are _not_
global either — each repo owns its own via devenv.

## Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using a
YubiKey-based age identity.

- Encrypted files live in `secrets/`, split by concern:
  - `env.yaml` — environment secrets (`GITHUB_TOKEN`, `GITLAB_TOKEN`) that get
    exported into the shell at login. Edit with `sece` (alias for
    `sops $NIXCONF/secrets/env.yaml`).
  - `secrets.yaml` — plain secrets that are **not** loaded into the shell
    environment (`NEXTCLOUD_PASSWORD`, ...). Edit with `sec` (alias for
    `sops $NIXCONF/secrets/secrets.yaml`).
- The module `modules/system/sops.nix` wires sops into NixOS: default sops file
  (`env.yaml`), age key file (`/etc/yubi-age-identity`), age-plugin-yubikey,
  and exposes a home-manager `sops` feature that decrypts `GITHUB_TOKEN` to
  `~/.config/sops-nix/secrets/GITHUB_TOKEN`. The feature is shared by every
  home-manager profile: NixOS hosts with the `sops` feature, standalone Linux
  profiles, and the macOS home-manager config. It also defines the `sec`/`sece`
  aliases.
- The sops module exports env secrets (`env.yaml`) into `$GITHUB_TOKEN` at
  login (only when the decrypted secret is readable), so `gh` works out of the
  box on any profile with sops enabled. It also exports `SOPS_AGE_KEY_FILE`, so
  plain `sops` works in any shell, including `devenv shell`.
- The age identity and SSH keys are stored under `config/` and referenced by the
  feature modules. Decryption requires the YubiKey, except on the workstation:
  it has no USB port for the YubiKey, so it decrypts with a software age key
  (`~/.config/sops/age/keys.txt`) instead. That key's public half is a second
  recipient in `.sops.yaml`, so every secret stays decryptable on both the
  YubiKey and the workstation. The sops module exposes `modules.sops.ageKeyFile`
  and `modules.sops.useYubikey` for hosts that need the same fallback. Re-keying
  after adding recipients is `sops updatekeys secrets/env.yaml secrets/secrets.yaml`
  (run from a machine with the YubiKey).
- GitLab tooling (`glab`, the `gitlab.nvim` LazyVim plugin, and the
  `GITLAB_TOKEN` secret) lives in the standalone `gitlab` feature module and is
  only enabled on the `alexis.pigeon@RNSL-APIGEON5` home-manager profile.

## Nextcloud

The `nextcloud` feature module (`modules/system/nextcloud.nix`) mounts the
homelab Nextcloud WebDAV share (`https://nextcloud.alexyz.hl`) like a local
drive. The password lives in `secrets/secrets.yaml` under `NEXTCLOUD_PASSWORD`
(never exported into the shell) and is decrypted by sops on each mount, so no
plaintext credentials are stored anywhere.

- **Linux** (`modules.nextcloud.enable`): davfs2 true mount via fstab at
  `/mnt/nextcloud` (`rw,user,noauto`) on NixOS hosts; standalone profiles mount
  `~/nextcloud` with `mount.davfs`. Certificates come from Let's Encrypt
  (Cloudflare DNS), so davfs2/rclone verify against the public trust store.
- **macOS** (`modules.nextcloudRclone.enable`): davfs2 is Linux-only, so the
  mount uses `rclone` + macFUSE (installed via the `macfuse` Homebrew cask),
  mounting `~/nextcloud`.
- Aliases everywhere: `ncm` mounts, `ncu` unmounts.

New secrets are created on a machine with the YubiKey (see above); if one is
created from the workstation it must be re-keyed with
`sops updatekeys secrets/secrets.yaml` before other hosts can decrypt it.

## Installer / ISO

Boot from the `installer-iso` USB (Ventoy) and run `nixos-installer` — a guided
flow that:

1. Lets you select the host to install (`headless-worker` / `workstation`).
1. Detects your YubiKey (workstation) and offers FIDO2 enrollment for LUKS +
   sudo.
1. Lists disks with `lsblk` and prompts with `gum choose` (with a data-loss
   warning).
1. Checks network, prompts for the user password, and shows a summary.
1. Generates a disko config for the selected host, partitions with
   `disko --mode destroy,format,mount`, then installs with `nixos-install`.
1. Copies the flake into `/etc/nixos` and provisions the YubiKey PAM mapping
   for login/sudo.

To build and copy the ISO to a Ventoy USB:

```bash
./scripts/build-iso.sh                    # auto-detects the plugged-in Ventoy USB
./scripts/build-iso.sh -e                 # auto-detect + unmount and power off USB after
```

A pre-baked copy of the flake ships inside the ISO at `/iso/nixconf`.

## Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- `$NIXCONF` env var pointing to this repo (set automatically by the shell
  module).
- YubiKey for age/sops decryption and FIDO2 auth (workstation, headless-worker).
- The test-suite prerequisites — come free through `devenv shell` or the NixOS
  `devenv` feature.
