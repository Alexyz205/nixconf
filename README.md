# NixOS Config

Project memory for learning NixOS by building a **custom bootable ISO image** (live + installer) with our own packages and configuration.

## Objective

Learn NixOS the practical way: build our own ISO that boots into a live environment containing our packages, and installs a **hardened** NixOS system with declarative partitioning.

## Status & Log

- [x] Read https://nix.dev/tutorials/nixos/building-bootable-iso-image
- [x] Chose **Flakes** (modern, reproducible) instead of the tutorial's classic `NIX_PATH` + `nixos-generators`
- [x] Created `flake.nix` (nixpkgs pinned via flake.lock) + `iso.nix` (ISO customizations)
- [x] Designed the **secure target system**: LUKS2 encryption, Btrfs subvolumes, systemd-boot, hardened SSH
- [x] Added **disko** for declarative partitioning (`disko-config.nix`) + secure base system (`system.nix`)
- [x] Added **sops-nix + age** scaffolding for a GitHub deploy key (`secrets.nix`, `.sops.yaml`) — encrypted private-repo access
- [ ] Install Nix on host machine
- [ ] Build the ISO (first build downloads the whole world, takes a while)
- [ ] Test ISO in a VM (e.g. QEMU)
- [ ] Install the secure system on real hardware via `disko-install`
- [ ] (Later) Extract config from an installed machine → manage everything from this repo

## Design decisions (security-focused)

| Topic | Choice | Why |
|-------|--------|-----|
| Flakes | `nixpkgs` + `disko` inputs, pinned via `flake.lock` | Reproducible builds |
| Partitioning | **disko** (declarative) | Partitioning as code, reproducible, re-runnable |
| Encryption | **LUKS2**, interactive passphrase | Full-disk encryption at rest |
| Filesystem | **Btrfs** subvolumes (`/`, `/home`, `/nix`, swapfile) | Compression (zstd), snapshots/rollback later |
| Bootloader | **systemd-boot** (UEFI) | Simple, secure; TPM2 auto-unlock possible later |
| SSH | keys-only, no root login, **fail2ban** | No password brute-forcing |
| Firewall | Default deny, only SSH open | Minimal attack surface |

### Partition layout (from disko-config.nix)

```
GPT
├─ ESP (1G, vfat) -> /boot     unencrypted (UEFI reads it to start boot)
└─ LUKS2 (rest)   -> btrfs     everything else encrypted
    ├─ /root  -> /
    ├─ /nix   -> /nix
    ├─ /home  -> /home
    └─ /swap  -> 8G swapfile   (encrypted, inside LUKS)
```

## Requirements (install Nix on your host)

On any Linux machine, from https://nixos.org/download :

```sh
# Multi-user install, then enable flakes.
curl -L https://nixos.org/nix/install -o /tmp/install-nix.sh
sh /tmp/install-nix.sh
```

(Download the script instead of `curl | sh` so you can review it first.)

Then enable the flake feature:

```sh
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Check: `nix --version` and `nix flake show` (must not complain about flakes being disabled).

## Project structure

```
.
├── flake.nix        # inputs (nixpkgs, disko) + outputs (iso + default system config)
├── iso.nix          # live/installer ISO customizations (on top of official installer CD)
├── disko-config.nix # declarative partitioning: LUKS2 + btrfs subvolumes + swapfile
├── system.nix       # the secure target system installed from the ISO
├── secrets.nix      # sops-nix: encrypted GitHub deploy key + ssh/git config (enable after bootstrap)
├── .sops.yaml       # sops rules: which age keys can decrypt the secrets
├── secrets/         # encrypted secrets (sops secrets/secrets.yaml)
└── flake.lock       # pins exact nixpkgs/disko revisions (generated on first build)
```

Key insight: the flake **imports the official minimal installer module** (for the ISO) and the **disko module + disko config** (for the installed system).

## Build the ISO

```sh
# Build the ISO
nix build .#nixosConfigurations.iso.config.system.build.isoImage

# Result symlink points to result/iso/nixos-<version>-x86_64-linux.iso
ls -la result/iso/

# Test in a VM without flashing anything (QEMU)
qemu-system-x86_64 -m 2G -cdrom result/iso/*.iso -boot d
```

The standard NixOS ISO is hybrid: it boots on both **BIOS and UEFI** machines.

## Install the secure system from the ISO

Boot the ISO, connect to the network, then:

```sh
# 1. Get this repo on the live system
git clone <this-repo-url> && cd nixOS_config

# 2. Set your real disk (check `lsblk`; use /dev/disk/by-id/... if possible)
#    and edit disko-config.nix (device) + system.nix (hostname, username, SSH key)

# 3. Partition, format, mount and install in ONE step
sudo nix run github:nix-community/disko/latest#disko-install -- \
  --flake .#default --disk main /dev/disk/by-id/YOUR-DISK

# 4. Reboot, remove the USB stick, unlock with your LUKS passphrase
reboot
```

`disko-install` uses the **exact** partitioning declared in `disko-config.nix` — no manual `fdisk`. It does NOT write UEFI boot entries to the host NVRAM by default (safe for test disks); add `--write-efi-boot-entries` to register the boot entry on the real machine.

### After first boot (account is locked on purpose)

```sh
sudo passwd alexis   # set a real password (change username in system.nix)
# or drop your public key into openssh.authorizedKeys.keys in system.nix and rebuild
```

## What's in the ISO

Inherited from the official minimal installer (`installation-cd-minimal.nix`):

- Live environment, auto-login as `nixos` (empty password), passwordless `sudo`
- `sshd` running, console installer (`nixos-install`) for fresh installs
- NetworkManager, git, all-hardware enablement
- Memtest86+, USB + EFI boot support

Added by us in `iso.nix`:

- Latest Linux kernel (`linuxPackages_latest`)
- Extra filesystems for rescue work (btrfs, xfs, ntfs, cifs, ...)
- Packages: `curl wget htop tmux ripgrep fd vim nix-tree nix-output-monitor`

## Security measures in the installed system (system.nix)

- **LUKS2 full-disk encryption** (passphrase at boot)
- **Firewall**: default deny, only port 22 open
- **SSH**: password auth disabled, root login disabled, fail2ban enabled
- **GitHub deploy key** encrypted with sops-nix (never committed in plaintext)
- **Kernel hardening**: `lockKernelModules`, `dmesg_restrict`, `kptr_restrict`, rp_filter
- **Core dumps disabled**
- `nix` restricted to `wheel` group
- sudo requires password

## Private repos via encrypted deploy key (sops-nix + age)

The machine clones private repos using a **dedicated GitHub deploy key** stored **encrypted** in this repo with `sops-nix` + `age`. The raw private key is never committed.

### One-time bootstrap (do this before enabling sops in the config)

```sh
# 1. Create the machine's age keypair (root-only on the machine).
#    Do this once the machine is installed and you can SSH in.
ssh alexis@nixos
sudo mkdir -p /var/lib/sops-nix
sudo age-keygen -o /var/lib/sops-nix/key.txt   # public key printed
sudo chmod 600 /var/lib/sops-nix/key.txt
exit

# 2. Put the printed public key into .sops.yaml (replace AGE-PUBLIC-KEY).
#    You can read it anytime on the machine with:
#      sudo age-keygen -y /var/lib/sops-nix/key.txt

# 3. Generate a dedicated GitHub deploy key on your workstation
#    (never reuse your SSH login key):
ssh-keygen -t ed25519 -f github-deploy-key -C "nixos@github"
#    Add github-deploy-key.pub at github.com -> Settings -> SSH and GPG keys.

# 4. Create the encrypted secrets file. Needs sops CLI on your workstation:
#      nix shell nixpkgs#sops nixpkgs#age
sops secrets/secrets.yaml
#    Add key "github-deploy-key" = <content of github-deploy-key (private half)>, save.
#    The file is now encrypted - commit it as-is. Keep github-deploy-key (raw) private.
```

### Enable sops in the config

In `flake.nix` uncomment `sops-nix.nixosModules.sops` and `./secrets.nix`, then:

```sh
nixos-rebuild switch --flake .#default   # on the machine
git clone git@github.com:you/private-repo.git   # now works
```

`sops-nix` decrypts `secrets/secrets.yaml` during activation using the age key at `/var/lib/sops-nix/key.txt` and writes `~/.ssh/github-deploy-key` (mode 0600). SSH is pinned to use only that key for `github.com`.

## Toolchain bootstrap: dotfiles in any container

The dev environment (shell, nvim, tmux, mise + language runtimes, ...) lives in the **dotfiles repo**
(`git@github.com:Alexyz205/dotfiles.git`, public). `install` runs `setup_dotfiles` (symlinks + submodules) then
`scripts/install_packages.sh` (installs `mise` via `curl -fsSL https://mise.run | sh` and installs the tools from
`config/mise/config.toml`). `system.nix` installs only the `mise` binary + system tools declaratively; runtimes come from
mise per-user so versions can switch per project.

### In any devcontainer (devpod / podman / VS Code)

`dotfiles/.devcontainer/devcontainer.json` has **no `features`**. `postCreateCommand` bootstraps everything:

1. `git config --global url."https://github.com/".insteadOf "git@github.com:"` — rewrites the SSH-URLed submodules
   (`nvim`, `tmux`, `scripts`) so they clone over HTTPS too.
2. `git clone --recursive https://github.com/Alexyz205/dotfiles.git "$HOME/dotfiles"`
3. `bash "$HOME/dotfiles/install"`

All repos are public today, so **no auth is needed** — the same `postCreateCommand` works in any container. If a repo
goes private, either switch to the SSH URL (DevPod forwards the host SSH agent automatically) or use a GitHub token via a
git credentials helper.

### On the NixOS machine (after first boot)

```sh
git clone git@github.com:Alexyz205/dotfiles.git ~/dotfiles
bash ~/dotfiles/install
```

Once sops is enabled, `~/.ssh/github-deploy-key` exists and SSH is pinned to it for `github.com`. Note: a deploy key
authorizes **one repo only** — for private submodules you'd need per-repo deploy keys or a user key in `ssh-agent`.

### Containers on the machine (podman, rootless)

- `virtualisation.podman` is enabled in `system.nix` (dockerCompat + `/run/docker.sock` for the `podman` group, weekly
  auto-prune). Rootless podman uses a per-user socket automatically.
- Background rootless containers need the user session to keep running after logout:
  `sudo loginctl enable-linger alexis`
- `devpod` is installed system-wide; workspaces run against the user's rootless podman socket.

## Concepts to learn along the way

| Concept | Where to look |
|---------|---------------|
| Flakes | https://nix.dev/concepts/flakes |
| NixOS module system | https://nix.dev/tutorials/module-system/ |
| disko (declarative partitioning) | https://github.com/nix-community/disko |
| disko-install docs | https://github.com/nix-community/disko/blob/master/docs/disko-install.md |
| Building images cross-platform | https://github.com/nix-community/nixos-generators |
| Alternative live CD guide | https://wiki.nixos.org/wiki/Creating_a_NixOS_live_CD |
| Installing NixOS from the ISO | https://nixos.org/manual/nixos/stable/#sec-installation |
| systemd-boot / bootloader | https://wiki.nixos.org/wiki/Bootloader |

## Troubleshooting

- **`flake` attribute not recognized** → flakes not enabled, see Requirements.
- **Build too slow** → normal on first run; later builds are cached/incremental.
- **ISO doesn't boot on old hardware** → check if the target is BIOS vs UEFI; our ISO covers both, but the installed system targets UEFI only (systemd-boot).
- **LUKS passphrase forgotten** → keep a printed backup; there is no backdoor.
- **nixos user password on ISO** → `passwd nixos` in the live env (empty by default).

## Next steps / roadmap

- [x] Design toolchain bootstrap: devcontainer `postCreateCommand` (clone dotfiles → `./install`) in `dotfiles/.devcontainer/devcontainer.json`
- [ ] Install Nix on host, build + test ISO in QEMU
- [ ] Set real disk device, hostname, username, SSH key; install on hardware
- [ ] Set up GitHub deploy key + enable sops-nix (README "Private repos")
- [ ] After first boot: clone dotfiles + run `./install`, `sudo loginctl enable-linger alexis`
- [ ] Add a `hosts/` structure when you get more machines
- [ ] Pin to a stable nixpkgs release for reproducibility (edit `flake.nix`)
- [ ] Add CPU microcode + GPU drivers (hardware-specific, in `system.nix`)
- [ ] Optional security upgrades: TPM2 auto-unlock, Secure Boot (lanzaboote), AppArmor, Btrfs snapshots
- [ ] Preconfigure SSH keys in the ISO for headless installs
- [ ] Automate the build with CI (build ISO on every push)
