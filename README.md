# nixconf

Dendritic NixOS configuration built on flake-parts + import-tree + home-manager.
One repo drives every machine and environment you own: NixOS desktops and
servers, nix-darwin laptops, Proxmox VMs, a USB installer ISO, and standalone
home-manager profiles — all sharing the same feature modules.

## Architecture

The flake entry point (`flake.nix`) is tiny: it delegates everything to
flake-parts, and import-tree recursively loads every `*.nix` file under
`modules/` as a flake-parts module. Feature modules declare both a NixOS side
(`flake.modules.nixos.<feature>`) and, where relevant, a home-manager side
(`flake.modules.homeManager.<feature>`), and each host mixes them via its
`features` list.

Each tool module is self-contained: it owns its `enable` option, the packages
it installs, and its zsh aliases. Enabling a feature is one line
(`modules.<feature>.enable = true`) and the aliases come along. The `shell`
module is the exception: it centralizes the environment and the
platform-specific rebuild aliases (`nr`/`hm`/`dr` sets), gated per platform
(see [Commands](#commands)).

```
flake.nix               # Entry point: flake-parts + import-tree
devenv.nix / devenv.yaml# Dev environment for this repo (LSPs, formatters, test tooling)
modules/
├── flake/              # options.nix (option types), home-manager.nix (standalone configs), tools.nix (.#tools profile)
├── hosts/              # One file per machine / image
├── system/             # boot, disko, network, nix, podman, sops, security, ssh, users, yubikey
├── shell/              # shell, starship, tmux, zoxide, eza, bat, btop, yazi, ghostty
├── desktop/            # brave, claude, discord, hidden-apps, niri, noctalia, steam, youtube-music
└── dev/                # containers, devenv, git, gitlab, lazygit, lazyvim, opencode, packages
config/                 # Dotfiles & static assets referenced from feature modules
scripts/                # install.sh, test-all.sh, build-iso.sh
secrets/                # sops-encrypted secrets
```

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
(`root@container` / `alexis@server`).

## Hosts

| Host              | Platform       | Type    | Key Features                                                        |
| ----------------- | -------------- | ------- | ------------------------------------------------------------------- |
| `macbook`         | aarch64-darwin | Laptop  | nix-darwin, Homebrew, Ghostty                                       |
| `workstation`     | x86_64-linux   | Desktop | Niri WM, Catppuccin (stylix), greetd, pipewire, YubiKey LUKS + sudo |
| `headless-worker` | x86_64-linux   | Server  | systemd-networkd, btrfs disko, SSH via YubiKey key, weekly GC       |
| `proxmox-vm`      | x86_64-linux   | VM      | cloud-init, Proxmox image, qemu-guest, minimal                      |
| `installer-iso`   | x86_64-linux   | USB ISO | Guided installer script with YubiKey auth                           |

Standalone home-manager profiles (`flake.homeConfigurations`):

| Config                        | Username      | Platform       | Notes                        |
| ----------------------------- | ------------- | -------------- | ---------------------------- |
| `alexis@macos`                | alexis        | aarch64-darwin | macOS profile                |
| `alexis@linux`                | alexis        | x86_64-linux   | Linux profile                |
| `alexis.pigeon@RNSL-APIGEON5` | alexis.pigeon | x86_64-linux   | Professional machine profile |

Hosts are referenced by their flake attribute: `nixosConfigurations.workstation`,
`darwinConfigurations.macbook`, `homeConfigurations."alexis@linux"`, etc.

## Commands

Rebuild aliases are zsh aliases defined by the `shell` module and gated per
platform: NixOS hosts get the `nixos-rebuild` set, nix-darwin the
`darwin-rebuild` set, and standalone home-manager profiles the `home-manager`
set. The `nix` flake aliases exist on every platform. All aliases use the
`$NIXCONF` env var.

### General (every platform)

```bash
nc   # nix flake check $NIXCONF
nu   # nix flake update $NIXCONF
nl   # nix flake lock $NIXCONF
ngc  # nix store gc
ngo  # nix store optimise
```

### NixOS

```bash
nr   # sudo nixos-rebuild switch --flake $NIXCONF
nrb  # nixos-rebuild build --flake $NIXCONF
nrt  # nixos-rebuild test --flake $NIXCONF
```

### macOS (nix-darwin)

```bash
dr   # darwin-rebuild switch --flake $NIXCONF
drb  # darwin-rebuild build --flake $NIXCONF
drc  # darwin-rebuild check --flake $NIXCONF
```

### Home-manager (standalone)

```bash
hm   # home-manager switch --flake $NIXCONF
hmb  # home-manager build --flake $NIXCONF
hmc  # home-manager build --flake $NIXCONF --check
```

### Tool aliases

Each tool module ships its own `enable` flag, packages, and aliases:

| Module               | Aliases                                                        |
| -------------------- | -------------------------------------------------------------- |
| `eza`                | `ls`, `la`, `ll`, `lt`, `lta`, `ltl`, `ldir`, `lm`, `lz`       |
| `git`                | `g`, `ga`, `gc`, `gcm`, `gco`, `gd`, `gl`, `gp`, `gP`, `gs`    |
| `lazygit`            | `lg`                                                           |
| `tmux`               | `t` (`new-session -A -s dev`)                                  |
| `lazyvim`            | `v`                                                            |
| `containers`         | `d`, `dc`, `ld`, `dru`, `ds`, `du`                             |
| `gitlab` (RNSL only) | `gm`, `gml`, `gmv`, `gmc`, `gma`, `gmm`, `gci`, `gcil`, `gciv` |
| `shell`              | `nf`, `repos`, `f`, `p`, `e`, `c`, `reload`                    |

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

## Dev environment (devenv)

Devenv provides the shell the test suite needs and is the template for any new
repository you start.

### For this repo

`devenv.nix` at the root installs what `scripts/test-all.sh` requires
(`disko` for the disko test, `shellcheck` for linting) and enables the Nix
language shell. It also owns the LSPs and formatters that LazyVim picks up
from `$PATH` (see [For a new project](#for-a-new--other-project)): `marksman`,
`yaml-language-server`, `vscode-json-languageserver`, `taplo`, `ruff`,
`prettierd`, `markdownlint-cli`, `nixfmt`, plus `nil`, `basedpyright` and
`shfmt`/`shellcheck` via the `languages.nix`/`languages.python`/
`languages.shell` batteries. Enter it with:

```bash
devenv shell        # drop into the dev shell
devenv up           # run services / stay resident (here: no services)
```

On NixOS hosts the `modules.dev.devenv` feature is enabled, which installs
`devenv` system-wide and adds a zsh hook so devenv **auto-activates** when
you `cd` into a repo that has its own `devenv.nix`. (Same behavior is provided
for standalone home-manager profiles.)

### For a new / other project

This repo's own `devenv.nix` is the reference template — copy it into any new
repo root and trim to taste:

```bash
cp $NIXCONF/devenv.nix $REPO/devenv.nix
devenv shell        # now enter that repo's dev environment
```

The mental model: LazyVim itself (the `lazyvim` feature) only provides
neovim + config + aliases — **LSPs and formatters live in each repo's
`devenv.nix`**, so they're available from `$PATH` inside the activated dev shell:

- **`packages`** — raw nixpkgs tools (neovim, git, lazygit, gh) plus the LSP
  baseline with no language battery: `marksman`, `yaml-language-server`,
  `vscode-json-languageserver`, `taplo`, `ruff`, `prettierd`, `markdownlint-cli`.
- **`languages`** — real compiler/runtime + matching LSP batteries. Enable only
  what the repo uses: `nix` (→ `nil`, `statix`, `deadnix`), `python` (→
  `basedpyright`), `shell` (→ `shfmt`, `shellcheck`), `node`, `typescript`, `c`,
  `cpp`, `rust`, `go`, … LazyVim finds the LSP from `$PATH`.
- **`env`** — shell environment variables (kept in sync with
  `devcontainer.json`).
- **`enterShell`** — runs when entering `devenv shell`.
- **`tasks`** — project commands via `devenv tasks run <name>` (`dev`, `build`,
  `test`, `lint`, `fmt`); also reachable through the TV `devenv-tasks` channel.

Anything that's not already global on NixOS (C++/Rust/Go toolchains, language-
specific compiler versions) belongs in the repo's `devenv.nix`, not in nixconf.
The LazyVim LSPs are _not_ global either — each repo owns its own via devenv.

## Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using a
YubiKey-based age identity.

- Encrypted files live in `secrets/`, split by concern:
  - `env.yaml` — environment secrets (`GITHUB_TOKEN`, `GITLAB_TOKEN`) that get
    exported into the shell at login. Edit with `sece` (alias for
    `sops $NIXCONF/secrets/env.yaml`).
  - `secrets.yaml` — plain secrets that are **not** loaded into the shell
    environment. Edit with `sec` (alias for
    `sops $NIXCONF/secrets/secrets.yaml`).
- The module `modules/system/sops.nix` wires sops into NixOS: default sops file
  (`env.yaml`), age key file (`/etc/yubi-age-identity`), age-plugin-yubikey,
  and exposes a home-manager `sops` feature
  that decrypts `GITHUB_TOKEN` to
  `~/.config/sops-nix/secrets/GITHUB_TOKEN` (via the sops-nix home-manager
  module, using the repo's age identity as an out-of-store symlink). The
  feature is shared by every home-manager profile: NixOS hosts with the
  `sops` feature, standalone Linux profiles, and the macOS home-manager
  config. It also defines the `sec`/`sece` aliases.
- The sops module exports env secrets (`env.yaml`) into `$GITHUB_TOKEN` at
  login (only when the decrypted secret is readable), so `gh` works out of the
  box on any profile with sops enabled.
- GitLab tooling (`glab`, the `gitlab.nvim` LazyVim plugin, and the
  `GITLAB_TOKEN` secret) lives in the standalone `gitlab` feature module and is
  only enabled on the `alexis.pigeon@RNSL-APIGEON5` home-manager profile.
- The age identity and SSH keys are stored under `config/` and referenced by the
  feature modules. Decryption requires the YubiKey (workstation,
  headless-worker, and any home-manager profile where the token is exported).

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
- `disko` and `shellcheck` — comes free through `devenv shell` or the NixOS
  `devenv` feature.
