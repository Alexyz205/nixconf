# Backups (restic)

`modules/system/backup.nix` wires a daily `restic` backup with pruning. It is
**off by default** because the repository URL is environment-specific (NAS,
S3/B2, SFTP). Once a destination exists, enabling it on a host is two settings
plus one secret.

The production target is the `backup-nas` host added by
`modules/hosts/backup-nas.nix` (192.168.1.113, SFTP-only `backup` user). The
current test box uses `modules/hosts/backup-nas-minimal.nix` at the same
address. Both are key-only for root and have no root password. The backup
module writes the matching `Host backup-nas` SSH block with
`IdentityFile /run/secrets/RESTIC_SSH_KEY`.

## 0. Create the restic SSH key (once)

```bash
ssh-keygen -t ed25519 -a 100 -C restic-backup -f ./restic-backup
# commit only the public key:
cp restic-backup.pub config/ssh/restic-backup.pub
# the private key goes into sops as RESTIC_SSH_KEY (never git)
```

On each client, add `RESTIC_SSH_KEY` to `secrets/secrets.yaml`; sops-nix
materialises it at `/run/secrets/RESTIC_SSH_KEY` with mode 0400. The NAS reads
`config/ssh/restic-backup.pub` and authorises the `backup` user with it.

## 1. Add the repository password

The password is a plain secret (never exported to the shell), so it belongs in
`secrets/secrets.yaml`:

```bash
sec    # add: RESTIC_PASSWORD: "<generated password>"
```

Generate a value with `openssl rand -base64 32`; keep it out of shell history
and process listings. `sops updatekeys secrets/secrets.yaml` is only needed when
the recipient list changes.

## 2. Enable it on the host

In `modules/hosts/headless-worker.nix` (or the workstation):

```nix
sops.secrets.RESTIC_PASSWORD = {
  sopsFile = ../../secrets/secrets.yaml;
};

modules.backup = {
  enable = true;
  repository = "sftp:backup-nas:/srv/restic/headless-worker";
  # defaults: /etc /home /var/lib, daily, keep 7 daily / 4 weekly / 6 monthly
};
```

`repository` also accepts `s3:https://s3.eu-central-003.backblazeb2.com/<bucket>`,
`rest:https://...`, or `rclone:<remote>:<path>`. `passwordFile` defaults to
`/run/secrets/RESTIC_PASSWORD`, which is where sops-nix materialises the
secret; it is passed as `--password-file` so it never appears in `ps` or the
Nix store.

## 3. Verify and restore

```bash
sudo systemctl start restic-backups-daily
restic-nas snapshots
restic-nas restore latest --target /tmp/restore --include /etc/nixos
```

Test a restore before relying on the backup. The timer is `Persistent = true`,
so a missed run (machine powered off) starts at the next boot.

## Default excludes

`modules.backup.exclude` keeps re-downloadable, volatile, or huge data out of
the snapshot:

- core dumps (`core.*`, `*.core`, `/var/lib/systemd/coredump`, `/var/crash`)
- game libraries (`~/Games`, Steam, PrismLauncher, `**/steamapps`)
- container storage (`/var/lib/containers`, `/var/lib/docker`, rootless
  `~/.local/share/containers`) and VM images (`/var/lib/libvirt`, `/var/lib/lxd`)
- caches (`~/.cache`, `/root/.cache`)

Container storage and VM disks are live and can change while restic reads them,
which aborts the run with a hash mismatch. Back those up with native
dumps/snapshots instead.

## What is not covered

- The repository itself needs a retention/lifecycle policy and its own backup
  (object storage with versioning, or a NAS with snapshots).
- The LUKS passphrase, the software age key on the workstation, and the
  `/var/lib/sbctl` Secure Boot keys must be backed up **outside** this
  repository (offline/paper), or a disk loss becomes unrecoverable.
- `restic-nas check --read-data-subset=5%` should run monthly to detect bit rot.

## Client shortcut

`modules.backup` installs `restic-nas`, which wraps
`sudo restic -r <repository> --password-file <passwordFile>` so the repository
and secrets path do not need to be repeated:

```bash
restic-nas snapshots
restic-nas ls latest
restic-nas find some-file
restic-nas stats latest
```

The `rs` alias expands to `restic-nas` in home-manager zsh (and system shells
that source the NixOS aliases). `restic-nas` itself works from any shell on a
host with `modules.backup.enable`.

## NAS side

`backup-nas` runs `modules/system/nas.nix`: ZFS pool `tank` with `longhorn`,
`restic`, and `backup` datasets, an NFSv4 export of
`/srv/nfs/longhorn` for Longhorn, SFTP-only `backup` user, ZFS auto-snapshots and
monthly scrub, NUT, and a weekly `syncoid` job to a USB pool named `offsite`.
See `proxmox-infra/hardware/nas-build-plan.md` for the hardware and first-boot
steps.
