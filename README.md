# nixconf

Dendritic NixOS configuration using flake-parts + import-tree + home-manager.

## Architecture

```
flake.nix               # Entry point: delegates to flake-parts + import-tree
modules/
├── flake/
│   ├── options.nix      # Defines flake.modules.{nixos,homeManager} option types
│   └── home-manager.nix # Standalone home-manager configs (macOS & Linux)
├── hosts/
│   ├── macbook.nix       # Apple Silicon (aarch64-darwin) via nix-darwin
│   ├── workstation.nix   # Desktop (x86_64-linux) NixOS + Niri + Catppuccin
│   ├── headless-worker.nix # Server NixOS (systemd-networkd, no DE)
│   ├── proxmox-vm.nix    # Minimal Proxmox VM template (cloud-init)
│   └── installer-iso.nix # USB installer ISO with guided script
├── shell.nix             # Zsh/Bash config, aliases, env vars
├── packages.nix          # Package profiles (basic, containers, security, devTools)
├── nix.nix               # Nix daemon settings
├── secrets.nix           # sops-nix integration
├── disko.nix             # Disk partitioning (disko)
├── ...
config/
├── shell/                # functions.sh, zsh-extra.zsh, bash-extra.sh
├── television/           # TV fuzzy-finder channels
├── opencode/             # OpenCode agent config
└── ...
```

## Hosts

| Host | Platform | Type | Key Features |
|------|----------|------|-------------|
| `macbook` | aarch64-darwin | Laptop | nix-darwin, Homebrew, Ghostty |
| `workstation` | x86_64-linux | Desktop | Niri WM, Catppuccin, SDDM, NixOS |
| `headless-worker` | x86_64-linux | Server | systemd-networkd, headless, weekly GC |
| `proxmox-vm` | x86_64-linux | VM | cloud-init, Proxmox image, minimal |
| `workstation-iso` | x86_64-linux | Installer | Guided installer with YubiKey auth |

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

## Secrets

Secrets managed via [sops-nix](https://github.com/Mic92/sops-nix) with YubiKey-based age identity:

```yaml
# .sops.yaml
keys:
  - &yubi age1yubikey1qdkk8ze7...
creation_rules:
  - path_regex: secrets/.+\.yaml$
    age: [*yubi]
```

## Installer

Boot from `workstation-iso` USB, run `nixos-installer` — guided flow with:

1. Host selection (headless-worker / workstation)
2. Disk selection via `gum choose`
3. YubiKey SSH unlock → clone private repo
4. `disko-install` with sops secrets

## Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`)
- `$NIXCONF` env var pointing to this repo (set automatically in shell module)
- YubiKey for age/sops decryption (workstation, headless-worker)
