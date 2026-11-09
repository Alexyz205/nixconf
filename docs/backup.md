# Backups (restic)

`modules/system/backup.nix` wires a daily `restic` backup with pruning. It is
**off by default** because the repository URL is environment-specific (NAS,
S3/B2, SFTP). Once a destination exists, enabling it on a host is two settings
plus one secret.

## 1. Add the repository password

The password is a plain secret (never exported to the shell), so it belongs in
`secrets/secrets.yaml`:

```bash
sec    # add: RESTIC_PASSWORD: "<generated password>"
# or non-interactively:
sops --set '["RESTIC_PASSWORD"] "s3cr3t"' secrets/secrets.yaml
sops updatekeys secrets/secrets.yaml
```

## 2. Enable it on the host

In `modules/hosts/headless-worker.nix` (or the workstation):

```nix
sops.secrets.RESTIC_PASSWORD = {
  sopsFile = ../../secrets/secrets.yaml;
};

modules.backup = {
  enable = true;
  repository = "sftp:backup@nas:/srv/restic/headless-worker";
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
sudo restic snapshots
sudo restic restore latest --target /tmp/restore --include /etc/nixos
```

Test a restore before relying on the backup. The timer is `Persistent = true`,
so a missed run (machine powered off) starts at the next boot.

## What is not covered

- The repository itself needs a retention/lifecycle policy and its own backup
  (object storage with versioning, or a NAS with snapshots).
- The LUKS passphrase, the software age key on the workstation, and the
  `/var/lib/sbctl` Secure Boot keys must be backed up **outside** this
  repository (offline/paper), or a disk loss becomes unrecoverable.
- `restic check --read-data-subset=5%` should run monthly to detect bit rot.
