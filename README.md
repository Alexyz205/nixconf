# NixOS Config

Dendritic-pattern NixOS configuration with `flake-parts` + `import-tree` + `wrapper-modules`.
Dual-purpose: runs as **NixOS system config** (on NixOS) or **standalone home-manager** (on any Linux).

## Quick Start

### On any Linux with Nix installed (standalone home-manager)

```sh
# Enable flakes first
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Apply packages, shell, tmux, starship, yazi, git, neovim config
nix run home-manager --extra-experimental-features 'nix-command flakes' -- switch --flake .#"alexis.pigeon"
```

### On NixOS

```sh
# Build & apply full system config
sudo nixos-rebuild switch --flake .#workstation   # GUI desktop (Niri + Noctalia)
sudo nixos-rebuild switch --flake .#server        # Headless server

# Build ISO
nix build .#nixosConfigurations.iso-proxmox.config.system.build.isoImage
nix build .#nixosConfigurations.iso-server.config.system.build.isoImage

# Test ISO in QEMU
qemu-system-x86_64 -m 2G -cdrom result/iso/*.iso -boot d
```

### Standalone packages (no home-manager)

```sh
nix run .#niri
nix run .#noctalia-shell
```

### Validate the flake

```sh
nix flake check
```

Validates all flake outputs (NixOS configs, home-manager, packages) for evaluation errors.

## Project structure

Uses the **Dendritic Pattern** with `flake-parts` + `import-tree`.
Every `.nix` file under `modules/` is auto-loaded as a flake-parts module.
Each feature module exports **two** submodule types:

- `flake.modules.nixos.<name>` — NixOS module with `options.modules.<name>.enable`
- `flake.modules.homeManager.<name>` — standalone home-manager module

```
.
├── flake.nix                 # flake-parts + import-tree (auto-loads everything)
├── packages.nix              # Shared home-manager packages list
├── modules/
│   ├── boot.nix              # systemd-boot (UEFI)
│   ├── disko.nix             # LUKS2 + Btrfs subvolumes
│   ├── network.nix           # Hostname, NetworkManager, firewall
│   ├── security.nix          # Kernel/runtime hardening
│   ├── ssh.nix               # Hardened OpenSSH + fail2ban
│   ├── podman.nix            # Rootless podman + docker socket
│   ├── nix.nix               # Nix daemon hardening
│   ├── users.nix             # User account + sudo policy
│   ├── secrets.nix           # sops-nix: encrypted deploy key
│   ├── shell.nix             # Zsh + Bash + aliases + env vars + symlinks
│   ├── packages.nix          # Package groups (basic, containers, security, dev)
│   ├── git.nix               # Git config + delta + gh/glab credentials
│   ├── starship.nix          # Starship prompt (Catppuccin Mocha)
│   ├── tmux.nix              # Tmux + TPM plugins + Catppuccin theme
│   ├── bat.nix               # Bat with Catppuccin theme
│   ├── eza.nix               # Eza (modern ls)
│   ├── zoxide.nix            # Zoxide (smart cd)
│   ├── lazygit.nix           # Lazygit (Catppuccin theme)
│   ├── yazi.nix              # Yazi file manager (Catppuccin theme)
│   ├── ghostty.nix           # Ghostty terminal (Catppuccin Mocha)
│   ├── lazyvim.nix           # Neovim + LazyVim + extras + override keymaps
│   ├── niri.nix              # Niri scrollable-tiling WM (wrapped via wrapper-modules)
│   ├── noctalia.nix          # Noctalia Shell bar (wrapped via wrapper-modules)
│   ├── config/               # Config files (bat themes, shell scripts, git, etc.)
│   │   ├── shell/
│   │   ├── bat/themes/
│   │   ├── delta/
│   │   ├── eza/
│   │   ├── git/
│   │   ├── ghostty/
│   │   ├── opencode/
│   │   └── television/
│   ├── home/                 # Home-manager data (lazyvim plugin configs)
│   ├── hosts/
│   │   ├── server.nix        # Headless server definition
│   │   ├── workstation.nix   # GUI desktop definition
│   │   ├── iso-proxmox.nix   # Proxmox VM ISO builder
│   │   └── iso-server.nix    # Server ISO builder
│   └── flake/
│       ├── options.nix       # Registers flake.modules.{nixos,homeManager} options
│       └── home-manager.nix  # Standalone home-manager entrypoint
├── secrets/
│   └── secrets.yaml          # Encrypted with sops-nix
├── .sops.yaml                # sops rules: which age keys can decrypt
└── flake.lock
```

**How it works:** each feature module exports two submodules. A NixOS host
imports `config.flake.modules.nixos` and toggles via `modules.<name>.enable`.
The standalone home-manager entry imports `config.flake.modules.homeManager` directly.

```nix
# modules/hosts/server.nix (simplified)
let
  features = with config.flake.modules.nixos; [
    boot network security ssh podman nix users shell packages disko secrets
    git starship tmux bat eza lazygit yazi zoxide
  ];
in {
  flake.nixosConfigurations.server = inputs.nixpkgs.lib.nixosSystem {
    modules = [ inputs.disko.nixosModules.disko
                inputs.sops-nix.nixosModules.sops
                inputs.home-manager.nixosModules.home-manager ] ++ features ++ [{
      networking.hostName = "server";
      modules = {
        users.userName = "alexis.pigeon";
        packages = { basic = true; containers = true; devTools = true; };
        shell.enable = true; git.enable = true; starship.enable = true;
      };
    }];
  };
}
```

## Available hosts

| Host             | Type       | Description                              |
|------------------|------------|------------------------------------------|
| `workstation`    | NixOS      | GUI desktop with Niri + Noctalia         |
| `server`         | NixOS      | Headless server (SSH, CLI, security)     |
| `iso-proxmox`    | ISO        | Proxmox VM installer + rescue ISO        |
| `iso-server`     | ISO        | Minimal server installer ISO             |
| `"alexis.pigeon"`| home-manager | Standalone config (any Linux w/ Nix)   |

## Design decisions

| Topic        | Choice                                                | Why                                             |
| ------------ | ----------------------------------------------------- | ----------------------------------------------- |
| Flakes       | nixpkgs + disko inputs, pinned via flake.lock         | Reproducible builds                             |
| Partitioning | disko (declarative)                                   | Partitioning as code, reproducible              |
| Encryption   | LUKS2, interactive passphrase                         | Full-disk encryption at rest                    |
| Filesystem   | Btrfs subvolumes (/, /home, /nix, swapfile)           | Compression (zstd), snapshots/rollback          |
| Bootloader   | systemd-boot (UEFI)                                   | Simple, secure; TPM2 auto-unlock possible later |
| SSH          | keys-only, no root login, fail2ban                    | No password brute-forcing                       |
| Firewall     | Default deny, only SSH open                           | Minimal attack surface                          |
| Architecture | Dendritic: flake-parts + import-tree + wrapper-modules | No flake.nix edits per new host or module      |

### Partition layout (from disko.nix)

```
GPT
├─ ESP (1G, vfat) -> /boot     unencrypted (UEFI reads it to start boot)
└─ LUKS2 (rest)   -> btrfs     everything else encrypted
    ├─ /root  -> /
    ├─ /nix   -> /nix
    ├─ /home  -> /home
    └─ /swap  -> 8G swapfile   (encrypted, inside LUKS)
```

## Install the secure system from the ISO

Boot the ISO, connect to the network, then:

```sh
# 1. Get this repo on the live system
git clone <this-repo-url> && cd nixOS_config

# 2. Set your real disk (check `lsblk`; use /dev/disk/by-id/... if possible)
#    and edit modules/hosts/<host>.nix (disko device + modules.* settings)

# 3. Partition, format, mount and install in ONE step
sudo nix run github:nix-community/disko/latest#disko-install -- \
  --flake .#workstation --disk main /dev/disk/by-id/YOUR-DISK

# 4. Reboot, remove the USB stick, unlock with your LUKS passphrase
reboot
```

## What's in the ISO

Inherited from the official minimal installer:

- Live environment, auto-login as `nixos` (empty password), passwordless `sudo`
- sshd running, console installer (nixos-install) for fresh installs
- NetworkManager, git, all-hardware enablement
- Memtest86+, USB + EFI boot support

Added by us:

- **proxmox**: Latest kernel + extra filesystems (btrfs, xfs, ntfs, cifs) + QEMU guest agent + rescue tools
- **server**: Same base + server-oriented package set

## Security measures

- **LUKS2 full-disk encryption** (passphrase at boot) — `disko.nix`
- **Firewall**: default deny, only port 22 open
- **SSH**: password auth disabled, root login disabled, fail2ban enabled
- **GitHub deploy key** encrypted with sops-nix (never committed in plaintext)
- **Kernel hardening**: lockKernelModules, dmesg_restrict, kptr_restrict, rp_filter
- **Core dumps disabled**
- nix restricted to wheel group
- sudo requires password

## Private repos via encrypted deploy key (sops-nix + age)

See the [secrets module](modules/secrets.nix). Summary:

```sh
# On the installed machine, generate age key
sudo mkdir -p /var/lib/sops-nix
sudo age-keygen -o /var/lib/sops-nix/key.txt

# On workstation, add the public key to .sops.yaml, then:
sops secrets/secrets.yaml   # add key "github-deploy-key"

# The secrets module is enabled by importing it in the host config
# (no modules.secrets.enable toggle — it's always active when included)
```

## Concepts

| Concept                          | Where to look                                                              |
| -------------------------------- | -------------------------------------------------------------------------- |
| Flakes                           | <https://nix.dev/concepts/flakes>                                          |
| NixOS module system              | <https://nix.dev/tutorials/module-system/>                                 |
| disko (declarative partitioning) | <https://github.com/nix-community/disko>                                   |
| disko-install docs               | <https://github.com/nix-community/disko/blob/master/docs/disko-install.md> |
| Dendritic pattern                | <https://github.com/denful/import-tree>                                    |
| wrapper-modules                  | <https://github.com/BirdeeHub/nix-wrapper-modules>                         |
| home-manager                     | <https://github.com/nix-community/home-manager>                            |
| sops-nix                         | <https://github.com/Mic92/sops-nix>                                        |

## Troubleshooting

- **`flake` attribute not recognized** → flakes not enabled (see Requirements).
- **`The option .. does not exist`** → import-tree found a data file as a module; prefix with `_` or move out of `modules/`.
- **ISO doesn't boot on old hardware** → check BIOS vs UEFI target.
- **LUKS passphrase forgotten** → keep a printed backup; no backdoor.
