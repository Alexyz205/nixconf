# Hosts, deploys and rollbacks

## Inventory

| Flake output                             | Type          | Tier / notes                                                                                                                                                                                |
| ---------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `nixosConfigurations.workstation`        | NixOS desktop | `desktop` tier, disko + LUKS, NVIDIA, niri                                                                                                                                                  |
| `nixosConfigurations.rnsw-apigeon1`      | NixOS desktop | `desktop` tier, disko + LUKS on both NVMe (2 TB system + 512 GB `/data`), RTX 4090 (driver 620), Take-Two corporate stack; `alexis.pigeon` is the default session, `alexis` the local admin |
| `nixosConfigurations.headless-worker`    | NixOS server  | `server` tier, disko + btrfs, systemd-networkd                                                                                                                                              |
| `nixosConfigurations.backup-nas`         | NixOS NAS     | WTR production layout: `base` tier + ZFS/NFSv4/SFTP/restic/snapshots/NUT; see `proxmox-infra/hardware/nas-build-plan.md`                                                                    |
| `nixosConfigurations.backup-nas-minimal` | NixOS NAS     | **Current test NAS** (`192.168.1.113`): ZFS/NFSv4/SFTP/restic with key-only root (no password); no base/home-manager tier                                                                   |
| `nixosConfigurations.proxmox-vm`         | NixOS VM      | minimal (`nix`, `users`, `ssh`), qemu-guest + cloud-init                                                                                                                                    |
| `nixosConfigurations.installer-iso`      | USB ISO       | guided installer (`nixos-installer`)                                                                                                                                                        |
| `darwinConfigurations.macbook`           | nix-darwin    | Homebrew + Ghostty                                                                                                                                                                          |
| `homeConfigurations.*`                   | standalone HM | `alexis@linux`, `alexis@macos`, `alexis.pigeon@RNSL-APIGEON5`, `alexis@server`, `root@container`, `vscode@container`                                                                        |
| `deploy.nodes.headless-worker`           | deploy-rs     | push a locally built closure to the server                                                                                                                                                  |

Hosts are composed from tiers defined in `modules/flake/nixos.nix`: the tier
module imports each feature **and** enables it with `mkDefault`, so a host file
only lists deltas. Disable a tier feature with a plain `modules.<name>.enable =
false`, or override its settings (`modules.sops.useYubikey = false`).

The corporate workstation has its own install + enrollment runbook:
[docs/rnsw-apigeon1.md](rnsw-apigeon1.md).

## Rebuild

```bash
nr    # nh os switch $NIXCONF          (diff + nom output)
nrb   # nh os build $NIXCONF           (build without activating)
nrt   # nh os test $NIXCONF            (activate for testing only)
nro   # nh os boot $NIXCONF            (make the next boot use it)
dr    # nh darwin switch $NIXCONF
drb   # nh darwin build $NIXCONF
hm    # nh home switch $NIXCONF#<profile>
hmb   # nh home build $NIXCONF#<profile>
```

`drc` and `hmc` stay on `darwin-rebuild check` / `home-manager build --check`
because `nh` has no `check` subcommand. The `alexis.pigeon@...` profiles use
`nh home switch $NIXCONF` (no explicit key): nh resolves `$USER@$HOSTNAME`,
which matches the RNSL flake key.

Before switching, `nvd diff` (`nd`) shows exactly which packages and versions
change between the current and the next generation.

## Deploy to the server

The server is reachable over SSH (fail2ban + key-only auth). Build locally and
push the closure instead of building on the server:

```bash
dep      # deploy $NIXCONF#headless-worker
depr     # deploy --remote-build $NIXCONF#headless-worker
```

`deploy-rs` activates the profile and rolls back automatically if the new
system fails its activation check. It needs root SSH access and the server host
key in `~/.ssh/known_hosts` (first connection must be verified manually).

For a fresh machine, `nixos-anywhere` (installed on every profile) is the
supported path:

```bash
nixos-anywhere --flake .#headless-worker root@<ip>
```

## Work laptop (`rnsw-apigeon1`)

`rnsw-apigeon1` pulls two corporate artifacts from `packages.gametools.dev`:
the T2 Palo Alto root CA (`modules/system/corp-auth.nix`) and the SentinelOne
agent package (`modules/system/sentinelone.nix`). Both are fixed-output,
hash-pinned, and unreachable outside the corporate network.

Evaluation is network-independent on purpose. The CA is installed with
`security.pki.certificateFiles` (a store path), **not** `builtins.readFile`,
because reading a `fetchurl` output during evaluation is import-from-derivation:
it made every `nix eval`/dry-run of this host block on the corporate mirror.
So `nix flake check`, the pre-push suite and `nix build --dry-run .#rnsw-apigeon1`
work from home.

Building the host still needs the corp network (or a store/binary cache already
containing those two artifacts), so build it on the laptop itself or over VPN.
For an emergency push from an untrusted network:
`SKIP_NIXCONF_TESTS=1 git push`.

## Rollback

Every switch keeps the previous generation. From the boot menu pick the last
working entry, or from a running system:

```bash
nh os rollback                       # switch back to the previous generation
sudo nixos-rebuild switch --rollback # raw fallback
nro                                  # make the current config the boot default
```

`boot.loader.systemd-boot.configurationLimit = 10` and the weekly `nix.gc`
keep `/boot` and the store from filling up. `nix.gc.options` defaults to
`--delete-older-than 30d`; the server overrides it explicitly.

The workstation has no YubiKey port: it decrypts sops secrets with the software
age key at `~/.config/sops/age/keys.txt`. Back that file up separately; losing
it means re-keying every secret with the YubiKey.

## Root Nix config (Ubuntu work stations)

`nh clean`, `nixos-rebuild`, `nixos-install` and `sudo nix ...` read
`/etc/nix/nix.conf`, not the home-manager-generated `~/.config/nix/nix.conf`.
On a multi-user install, enable flakes there once:

```bash
sudo sh -c '
  grep -q "^experimental-features" /etc/nix/nix.conf ||
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
'
sudo systemctl restart nix-daemon
```

`scripts/install.sh` does this automatically for new machines. Without it,
`nh clean all` removes the old profiles and then fails at the final
`nix store gc` with `experimental Nix feature 'nix-command' is disabled`.

## Add a host

1. Create `modules/hosts/<name>.nix` (import-tree picks it up automatically).
2. Use `config.nixconf.mkHostCommon { hostName = "<name>"; stateVersion = "26.05"; }`
   and one tier: `config.nixconf.nixosFeatures.base|server|desktop`.
3. Add the disko module and set `disko.devices.disk.main.device` (or reuse
   `config.nixconf.mkBtrfsLayout`).
4. Add the host to `nixosConfigurations` (the tested host list in
   `scripts/test-all.sh` is derived from the flake, nothing to edit).
5. If the host needs a new flake input, declare it in the feature module and
   run `nix run .#write-flake`; never edit `flake.nix` by hand.
6. `nix flake check`, then install with the ISO or `nixos-anywhere`.

## Secrets

```bash
sec    # sops $NIXCONF/secrets/secrets.yaml   (personal host secrets)
sece   # sops $NIXCONF/secrets/corp.yaml      (corporate host secrets)
secx   # sops <file>                          (same key, any sops file, e.g. corp.yaml)
```

The three aliases use `modules.sops.interactiveAgeKeyFile`, which defaults to the
YubiKey identity when `useYubikey = true` (touch required, cached 15 s) and to
`modules.sops.ageKeyFile` otherwise. `modules.sops.ageKeyFile` stays the identity
used by unattended activation, so a host can boot with a software key and still
edit secrets with the YubiKey.

`secrets/secrets.yaml` is the default sops file for every host that does not
override `modules.sops.secretsFile`: the Nextcloud password and the restic
credentials live there, so `sops.secrets.<NAME> = { }` needs no `sopsFile`.
Corporate hosts pin `modules.sops.secretsFile` to `secrets/corp.yaml` (LDAP bind
password, NAS, Nessus and SentinelOne keys) and declare those secrets with an
explicit `sopsFile = ../../secrets/corp.yaml`.

Git `user.name`/`user.email` and the GitLab/GitHub credentials are **not** sops
secrets. `modules/dev/git.nix` switches identity by directory (`~/repos/work/`,
`~/repos/personal/`), and `gh`/`glab` keep their tokens in the OS keyring after a
one-time login:

```bash
gh auth login --hostname github.com --git-protocol https --web \
  --scopes "repo,read:org,gist,workflow"
glab auth login --hostname gitlab.alexyz.org --web
glab auth login --hostname git.dxyz.pro --web
# Self-managed OAuth app: redirect http://localhost:7171/auth/redirect,
# Confidential off, scopes openid profile read_user write_repository api.
glab config set client_id <application-id> --host git.dxyz.pro
# The login flow defaults ssh_hostname to github.com.
glab config set ssh_hostname git.dxyz.pro --host git.dxyz.pro
```

Only the machine that runs the login can use that host; the repo, sops files and
Nix store contain no CLI token. Run `gh auth status` / `glab auth status --all`
to verify. GitLab OAuth access tokens expire and are renewed by the next
authenticated `glab` call, which is also what `gitlab.nvim` relies on.

`modules.users.homeUsers` lists every account that gets a home-manager profile.
On `rnsw-apigeon1` it is `[ "alexis" "alexis.pigeon" ]`, so both accounts get
the same feature modules. The sops identity differs: `alexis` uses the rnsw
software key for unattended `corp.yaml` access, while `alexis.pigeon` uses the
YubiKey identity (`modules.sops.interactiveYubikey = true`), so `sec`/`sece`
work with a touch and no private key is copied into the corporate home.

After adding a recipient or editing from a machine other than the YubiKey host,
re-key with `sops updatekeys secrets/secrets.yaml`. The former split
`env.yaml` is merged by `scripts/migrate-secrets-single-file.sh` (idempotent,
`--dry-run` supported).
