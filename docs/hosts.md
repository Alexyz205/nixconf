# Hosts, deploys and rollbacks

## Inventory

| Flake output                          | Type          | Tier / notes                                                                                                         |
| ------------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------- |
| `nixosConfigurations.workstation`     | NixOS desktop | `desktop` tier, disko + LUKS, NVIDIA, niri                                                                           |
| `nixosConfigurations.headless-worker` | NixOS server  | `server` tier, disko + btrfs, systemd-networkd                                                                       |
| `nixosConfigurations.proxmox-vm`      | NixOS VM      | minimal (`nix`, `users`, `ssh`), qemu-guest + cloud-init                                                             |
| `nixosConfigurations.installer-iso`   | USB ISO       | guided installer (`nixos-installer`)                                                                                 |
| `darwinConfigurations.macbook`        | nix-darwin    | Homebrew + Ghostty                                                                                                   |
| `homeConfigurations.*`                | standalone HM | `alexis@linux`, `alexis@macos`, `alexis.pigeon@RNSL-APIGEON5`, `alexis@server`, `root@container`, `vscode@container` |
| `deploy.nodes.headless-worker`        | deploy-rs     | push a locally built closure to the server                                                                           |

Hosts are composed from tiers defined in `modules/flake/nixos.nix`: the tier
module imports each feature **and** enables it with `mkDefault`, so a host file
only lists deltas. Disable a tier feature with a plain `modules.<name>.enable =
false`, or override its settings (`modules.sops.useYubikey = false`).

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
sec    # sops $NIXCONF/secrets/secrets.yaml   (not exported to the shell)
sece   # sops $NIXCONF/secrets/env.yaml       (exported as env vars at login)
```

The default sops file for NixOS is `env.yaml`. Secrets that must not become
shell variables (Nextcloud password, restic password) belong in
`secrets/secrets.yaml` and are referenced with an explicit `sopsFile`:

```nix
sops.secrets.RESTIC_PASSWORD = {
  sopsFile = ../../secrets/secrets.yaml;
};
```

After adding a recipient or editing from a machine other than the YubiKey host,
re-key with `sops updatekeys secrets/env.yaml secrets/secrets.yaml`.
