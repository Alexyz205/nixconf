# Impermanence (ephemeral root)

`modules.impermanence.enable = true` wires
`environment.persistence."/persistent"` and, by default, mounts `/` as tmpfs.
It does **not** make the disk layout ephemeral by itself; the host's disko
config must provide a separate `/persistent` subvolume.

Both NixOS hosts use it:

| Host              | Root  | Persistent mounts              | LUKS |
| ----------------- | ----- | ------------------------------ | ---- |
| `workstation`     | tmpfs | `/home`, `/nix`, `/persistent` | yes  |
| `headless-worker` | tmpfs | `/home`, `/nix`, `/persistent` | no   |

`/home` remains its own btrfs subvolume, so user data and the workstation's
software sops key (`~/.config/sops/age/keys.txt`) survive. That is why the host
configs set `userDirectories = [ ]`; persisting `.ssh` etc. is only needed when
`/home` is ephemeral too.

## Layout

`modules/system/disko.nix` keeps `/root` as the installer/recovery root and
adds:

```text
/            tmpfs (size=50% of RAM)     root, wiped every boot
/boot        ESP
/nix         btrfs subvolume             Nix store + generations (persistent)
/home        btrfs subvolume             user data (persistent)
/persistent  btrfs subvolume             system state (persistent)
/.swapvol    btrfs swapfile
/root        btrfs subvolume             unused after install; recovery only
```

The `impermanence` module sets `neededForBoot` on `/nix`, `/home` and
`/persistent`, and forces `/` to tmpfs. `/root` is still created by disko so
the installer can mount and install into it; it is not mounted at `/` at
runtime.

## What is persisted

System state (extend per host):

```text
/etc/machine-id
/etc/ssh
/etc/NetworkManager/system-connections   (workstation)
/var/log
/var/lib/nixos
/var/lib/systemd/coredump
/var/lib/NetworkManager                  (workstation)
/var/lib/bluetooth                       (workstation)
/var/lib/containers                      (podman)
/var/lib/sbctl                           (Secure Boot keys, when enabled)
```

User data is on `/home`, including `~/.ssh`, `~/.gnupg`, keyrings, direnv and
`~/.config/sops`.

The account password is the one piece of state that cannot be listed under
`environment.persistence.files`: `/etc/shadow` is written by the `users`
activation script **before** the persistence script runs, and impermanence
refuses to replace a non-empty file ("A file already exists at /etc/shadow!").
Hosts with ephemeral root therefore keep the crypt(3) hash as a file on the
persistent volume and point `modules.users.hashedPasswordFile` at it:

```nix
modules.users.hashedPasswordFile = "/persistent/etc/alexis.hash";
```

`scripts/migrate-impermanence.sh` extracts that hash from the running
`/etc/shadow`. Change the password by replacing the hash file (for example
`openssl passwd -6 > /persistent/etc/alexis.hash`), not with `passwd`; a sops
secret plus `hashedPasswordFile` is the fully declarative alternative.

## First install / migration

This is a disk change. The supported path is a **reinstall** (or creating the
subvolumes by hand on an existing disk before enabling the module).

For an existing install, `scripts/migrate-impermanence.sh` does the manual part
of step 1 below: it creates the `/persistent` subvolume from the btrfs top
level, mounts it, seeds the current machine state (SSH host keys, `machine-id`,
`/etc/shadow`, NetworkManager, bluetooth, containers, systemd state, logs) and
verifies the copies. It never formats anything, and the old `/root` subvolume
stays bootable as the previous generation.

```bash
sudo ./scripts/migrate-impermanence.sh --dry-run   # show the plan
sudo ./scripts/migrate-impermanence.sh             # do it
nrb && nro && sudo reboot
```

1. Build the ISO and re-image with disko (the installer uses the host's disko
   config and now creates `/persistent`).
2. Boot the installed system; verify:

   ```bash
   findmnt /                 # tmpfs
   findmnt /persistent       # btrfs subvolume
   findmnt /home
   findmnt /nix
   ```

3. Confirm the persisted paths exist under `/persistent` after the first boot
   (`/persistent/etc/ssh`, `/persistent/var/lib/nixos`, ...).
4. Move any state you need from the old root into `/persistent` while booted
   from the ISO or before the first ephemeral boot. The old `/root` subvolume
   is still on disk but unused; mount it manually if you need old files.

Do **not** switch an existing machine that lacks `/persistent` to this config:
activation expects the mount and the tmpfs root, and the disk will not have the
subvolume.

## Options

| Option                          | Default                            | Meaning                                               |
| ------------------------------- | ---------------------------------- | ----------------------------------------------------- |
| `modules.impermanence.enable`   | `false`                            | wire `environment.persistence` and tmpfs `/`          |
| `tmpfsRoot`                     | `true`                             | mount `/` as tmpfs; set false for btrfs-root rotation |
| `persistPath`                   | `"/persistent"`                    | surviving volume mount point                          |
| `directories` / `files`         | small safe set                     | system paths bind-mounted/linked into persistence     |
| `userDirectories` / `userFiles` | `.ssh`, `.gnupg`, keyrings, direnv | per-user paths; empty here because `/home` persists   |

## Recovery

- Generations live in `/nix`, so `nh`/`nixos-rebuild --rollback` and the boot
  menu still work.
- `/root` is not mounted; from the ISO run
  `mount -o subvol=root /dev/… /mnt` (or the LUKS device) to inspect old root
  data.
- `/persistent` is the only state that survives; back it up like any other
  data (restic; see `docs/backup.md`).
