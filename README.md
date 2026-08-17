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

```
flake.nix               # Entry point: flake-parts + import-tree
devenv.nix / devenv.yaml# Dev environment for this repo (test tooling)
modules/
├── flake/              # options.nix (option types), home-manager.nix (standalone configs)
├── hosts/              # One file per machine / image
├── system/             # boot, disko, network, nix, podman, secrets, security, ssh, users, yubikey
├── shell/              # shell, starship, tmux, zoxide, eza, bat, btop, lazygit, yazi, lazyvim, ghostty
├── desktop/            # niri, noctalia, brave
└── dev/                # devenv, git, packages
config/                 # Dotfiles & static assets referenced from feature modules
examples/dev-env/       # Per-project devenv + devcontainer template
scripts/                # test-all.sh, build-iso.sh
secrets/                # sops-encrypted secrets
```

## Hosts

| Host | Platform | Type | Key Features |
|------|----------|------|-------------|
| `macbook` | aarch64-darwin | Laptop | nix-darwin, Homebrew, Ghostty |
| `workstation` | x86_64-linux | Desktop | Niri WM, Catppuccin (stylix), greetd, pipewire, YubiKey LUKS + sudo |
| `headless-worker` | x86_64-linux | Server | systemd-networkd, btrfs disko, SSH via YubiKey key, weekly GC |
| `proxmox-vm` | x86_64-linux | VM | cloud-init, Proxmox image, qemu-guest, minimal |
| `installer-iso` | x86_64-linux | USB ISO | Guided installer script with YubiKey auth |

Standalone home-manager profiles (`flake.homeConfigurations`):

| Config | Username | Platform | Notes |
|--------|----------|----------|-------|
| `alexis@macos` | alexis | aarch64-darwin | macOS profile |
| `alexis@linux` | alexis | x86_64-linux | Linux profile |
| `alexis.pigeon@linux` | alexis.pigeon | x86_64-linux | Professional machine profile |

Hosts are referenced by their flake attribute: `nixosConfigurations.workstation`,
`darwinConfigurations.macbook`, `homeConfigurations."alexis@linux"`, etc.

## Commands

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

### General
```bash
nc   # nix flake check $NIXCONF
nu   # nix flake update $NIXCONF
nl   # nix flake lock $NIXCONF
ngc  # nix store gc
ngo  # nix store optimise
```

## Test suite

`scripts/test-all.sh` validates the whole repo:

```bash
./scripts/test-all.sh           # run all tests
./scripts/test-all.sh eval      # just evaluate configs
./scripts/test-all.sh -l        # list available tests
```

| Test | What it does |
|------|--------------|
| `flake` | `nix flake check` (all configs, options, checks) |
| `eval` | Dry-run builds every NixOS + home-manager config |
| `disko` | Disko dry-run for workstation & headless-worker |
| `iso` | Builds the `installer-iso` ISO image |
| `vm` | Builds the Proxmox VM image (`.#proxmox-vm`) |
| `shellcheck` | Lints `scripts/*.sh` |

## Dev environment (devenv)

Devenv provides the shell the test suite needs and is the template for any new
repository you start.

### For this repo

`devenv.nix` at the root installs what `scripts/test-all.sh` requires
(`disko` for the disko test, `shellcheck` for linting) and enables the Nix
language shell. Enter it with:

```bash
devenv shell        # drop into the dev shell
devenv up           # run services / stay resident (here: no services)
```

On NixOS hosts the `modules.dev.devenv` feature is enabled, which installs
`devenv` system-wide and adds a zsh/bash hook so devenv **auto-activates** when
you `cd` into a repo that has its own `devenv.nix`. (Same behavior is provided
for standalone home-manager profiles.)

### For a new / other project

Copy the template into any repo root:

```bash
cp -r $NIXCONF/examples/dev-env/. $REPO/
devenv shell        # now enter that repo's dev environment
```

The template ships `devenv.nix` + `.devcontainer/devcontainer.json` and wires
up LazyVim auto-detection:

- **`packages`** — raw nixpkgs tools (neovim, git, lazygit, gh, LSPs …).
- **`languages`** — real compiler/runtime + matching LSP batteries. Enable only
  what the repo uses: `nix`, `python`, `node`, `typescript`, `c`, `cpp`,
  `rust`, `go`, … LazyVim finds the LSP from `$PATH`.
- **`env`** — shell environment variables (kept in sync with
  `devcontainer.json`).
- **`enterShell`** — runs when entering `devenv shell`.
- **`tasks`** — project commands via `devenv tasks run <name>` (`dev`, `build`,
  `test`, `lint`, `fmt`); also reachable through the TV `devenv-tasks` channel.

Anything that's not already global on NixOS (C++/Rust/Go toolchains, language-
specific compiler versions) belongs in the repo's `devenv.nix`, not in nixconf.

## Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using a
YubiKey-based age identity.

```yaml
# .sops.yaml
keys:
  - &yubi age1yubikey1qdkk8ze7...
creation_rules:
  - path_regex: secrets/.+\.yaml$
    age: [*yubi]
```

- Encrypted files live in `secrets/` (e.g. `secrets.yaml` with `userPasswordHash`).
- The module `modules/system/secrets.nix` wires sops into NixOS: default sops
  file, age key file (`/etc/yubi-age-identity`), age-plugin-yubikey, and git
  identity (user name + email).
- The age identity and SSH keys are stored under `config/` and referenced by the
  feature modules. Decryption requires the YubiKey (workstation,
  headless-worker).

## Installer / ISO

Boot from the `installer-iso` USB (Ventoy) and run `nixos-installer` — a guided
flow that:

1. Lets you select the host to install (`headless-worker` / `workstation`).
2. Detects your YubiKey (workstation) and offers FIDO2 enrollment for LUKS +
   sudo.
3. Lists disks with `lsblk` and prompts with `gum choose` (with a data-loss
   warning).
4. Checks network, prompts for the user password, and shows a summary.
5. Generates a disko config for the selected host, partitions with
   `disko --mode destroy,format,mount`, then installs with `nixos-install`.
6. Copies the flake into `/etc/nixos` and provisions the YubiKey PAM mapping
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