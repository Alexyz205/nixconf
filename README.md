# NixOS Config

Dendritic-pattern NixOS configuration with `flake-parts` + `import-tree` + `wrapper-modules`.
Dual-purpose: runs as **NixOS system config** (on NixOS) or **standalone home-manager** (on any Linux).

## Quick Start

### On any Linux with Nix installed (standalone home-manager)

```sh
# Enable flakes first (nix needs this before home-manager's internal nix calls work)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# Apply packages, shell, tmux, starship, yazi, git, neovim config
# -b backup: on first switch home-manager takes over nix.conf itself, so the
#   manual file is moved to *.backup instead of failing on the clobber check.
nix run --extra-experimental-features 'nix-command flakes' home-manager -- switch --flake .#"alexis@macos" -b backup
nix run --extra-experimental-features 'nix-command flakes' home-manager -- switch --flake .#"alexis@linux" -b backup
```

### On NixOS

```sh
# Build & apply full system config
sudo nixos-rebuild switch --flake .#workstation   # GUI desktop (Niri + Noctalia)
sudo nixos-rebuild switch --flake .#server        # Headless server

# Build ISO
nix build .#nixosConfigurations.iso-proxmox.config.system.build.isoImage
nix build .#nixosConfigurations.iso-server.config.system.build.isoImage
nix build .#nixosConfigurations.iso-workstation.config.system.build.isoImage

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
│   ├── packages.nix          # Package groups (basic, containers, security, dev) for NixOS + home-manager
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
│   │   ├── lazyvim/
│   │   ├── sops/
│   │   │   └── yubi-age-identity   # YubiKey PIV age identity (not a secret)
│   │   └── television/
│   ├── hosts/
│   │   ├── server.nix        # Headless server definition
│   │   ├── workstation.nix   # GUI desktop definition
│   ├── iso/
│   │   ├── iso-proxmox.nix    # Proxmox VM ISO builder
│   │   ├── iso-server.nix     # Server ISO builder
│   │   └── iso-workstation.nix # Workstation installer ISO
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
        users.userName = "alexis";
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
| `iso-workstation`| ISO        | Workstation installer + rescue ISO       |
| `"alexis@macos"`| home-manager | Standalone config (macOS)                |
| `"alexis@linux"`| home-manager | Standalone config (any Linux w/ Nix)   |

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

## Install from the workstation ISO

The ISO embeds the full flake at `/etc/nixos/flake` — no internet needed, no cloning.
Boot the USB, then run a single interactive command:

```sh
install-workstation
```

It will:
1. List all available disks (with sizes) and ask which one to install on
2. Ask for confirmation (type `yes` to erase)
3. Run `disko-install` — partition, format, install, configure boot, and enroll your YubiKey
4. When disko prompts, touch the YubiKey → the token is enrolled automatically (keep the recovery QR it prints)
5. After completion: `sudo reboot`, remove the USB, touch the YubiKey to unlock

On first boot, the system activates sops-nix and decrypts the user password
using your YubiKey PIV slot (touch + PIN). SDDM then shows the `alexis` user.
Log in with the default password `changeme`.

One command, one touch, done.

## What's in the ISO

Inherited from the official minimal installer:

- Live environment, auto-login as `nixos` (empty password), passwordless `sudo`
- sshd running, console installer (nixos-install) for fresh installs
- NetworkManager, git, all-hardware enablement
- Memtest86+, USB + EFI boot support

Added by us:

- **proxmox**: Latest kernel + extra filesystems (btrfs, xfs, ntfs, cifs) + QEMU guest agent + rescue tools
- **server**: Same base + server-oriented package set
- **workstation**: Same base + YubiKey tools + the flake itself at `/etc/nixos/flake` (no cloning needed)

## Security measures

- **LUKS2 full-disk encryption**, unlockable with the FIDO2 YubiKey (touch) or the passphrase — `disko.nix` + `yubikey.nix`
- **Firewall**: default deny, only port 22 open
- **SSH**: password auth disabled, root login disabled, fail2ban enabled
- **SSH client**: FIDO2 resident YubiKey (`sk-ssh-ed25519@openssh.com`) for `git clone` and `ssh` to machines
- **sudo/login**: touch the YubiKey instead of typing the password (password stays as fallback)
- **sops-nix** for secrets (age keys, never plaintext)
- **Kernel hardening**: lockKernelModules, dmesg_restrict, kptr_restrict, rp_filter
- **Core dumps disabled**
- nix restricted to wheel group
- sudo requires password

## YubiKey (workstation)

Applied by `modules/yubikey.nix` when `modules.yubikey.*` are enabled (workstation:
`luksUnlock` + `sudoAuth` + `sshKey`). The config is the *runtime* half; the tokens
below are one-time enrollments that poke the disk/`/etc/pam.d`/credential databases
and therefore cannot be declarative.

```sh
# 1. LUKS unlock at boot: on a NEW install this is done by disko automatically
#    (see luksUnlock): just insert the YubiKey when it prompts, and keep the QR
#    recovery passphrase it prints. On an already-installed disk, run it once:
sudo cryptsetup luksDump /dev/disk/by-partlabel/disk-main-luks | head   # must say "LUKS 2"
sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/disk-main-luks
#    defaults = touch only. For touch + PIN use:
#      --fido2-with-client-pin=yes --fido2-with-user-presence=yes

# 2. Touch for sudo / login (pam_u2f, origin pam://<hostname> — re-run on each machine):
pamu2fcfg > ~/.config/Yubico/u2f_keys       # extra keys: pamu2fcfg -n >> ...

# 3. SSH: the key is resident on the YubiKey. Recover its (non-secret) handle ONCE
#    and commit it so every machine deployed from this flake picks it up:
ssh-keygen -K && mv ~/id_ed25519_sk modules/config/ssh/yubi_ed25519
#    The matching public half lives in modules/config/ssh/yubi_ed25519.pub — add it
#    to GitHub (Settings > SSH keys) and to ~/.ssh/authorized_keys on servers.

# 4. sops decryption (age-plugin-yubikey): generate a YubiKey PIV age identity
#    once per YubiKey. The identity file (not a secret) is committed; the private
#    key lives in the PIV slot and can never be extracted.
nix shell nixpkgs#age-plugin-yubikey --command age-plugin-yubikey --generate
#    Then copy the identity (AGE-PLUGIN-YUBIKEY-...) and public key
#    (age1yubikey...) to the repo:
#      - Identity  → modules/config/sops/yubi-age-identity
#      - Public key → .sops.yaml (as the age recipient)
#    (Already done for this flake — re-run only for a new YubiKey.)
#    Note: needs pcscd running. On NixOS it's automatic; on other distros:
#      sudo systemctl start pcscd
```

## Secrets with sops-nix

See the [secrets module](modules/secrets.nix). `sops.age.generateKey = true`
auto-creates `/var/lib/sops-nix/key.txt` on first activation. `secrets/secrets.yaml`
is a plaintext template (guarded so rebuilds never break); it contains a
`sample-secret` to test the pipeline end-to-end before adding your own.

```sh
# 1. Rebuild once so the host age key is generated (or create it manually):
sudo nixos-rebuild switch --flake .#workstation

# 2. Point sops at that host key and register it in .sops.yaml:
sudo age-keygen -y /var/lib/sops-nix/key.txt    # replace AGE-PUBLIC-KEY in .sops.yaml

# 3. Encrypt the template, then inspect the decrypted value on the machine:
sops updatekeys secrets/secrets.yaml
nixos-rebuild switch --flake .#workstation      # once sample-secret is referenced in the module
```

To deploy your own secret: add it to `secrets/secrets.yaml` with `sops` and declare
it under `sops.secrets.<name>` in `modules/secrets.nix` (uncomment the example).

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
