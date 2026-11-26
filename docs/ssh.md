# SSH: personal + corporate fleet

`modules/system/ssh.nix` owns the client config (`~/.ssh/config`) and the
key-only OpenSSH server. Personal/LAN hosts are declared there. Corporate hosts
are generated locally so internal names and addresses never enter this public
repository.

## Work fleet (`modules.ssh.workHosts`)

Enabled on:

- `rnsw-apigeon1` for the `alexis.pigeon` home-manager user.
- `alexis.pigeon@RNSL-APIGEON5` (the `workExtra` home-manager profile).

When enabled, home-manager activation runs `sync-work-ssh`, which reads the
`infra_management` Ansible inventory and writes:

```text
~/.ssh/config.d/work
```

The main config includes it with `Include ~/.ssh/config.d/*`, so aliases work
directly with `ssh`, `scp`, `rsync` and `ssh-copy-id`:

```bash
ssh tk2edcdxzci1
ssh tk2edcdxzci10
ssh-copy-id tk2edcdxzci1
```

Inventory default address/host/user come from the YAML (`ansible_host`,
`ansible_user`, and `ansible.cfg`'s `remote_user`). Windows CI hosts are
included; on this fleet the working account is `admapigeon` for both Linux and
Windows, while `rnsw_server1`/studio1 uses `alexis.pigeon`.

The generator is available without switching:

```bash
sync-work-ssh            # refresh the fragment
sync-work-ssh --check    # exit 1 if it is stale
sync-work-ssh --print    # inspect without writing
```

Default inventory:
`~/repos/work/infra_management/inventories/prod/inventory.yml` (override with
`NIXCONF_WORK_INVENTORY`). Missing inventory or a missing checkout is a no-op,
so personal machines never fail activation.

### Local-only hosts

Add hosts that are not in the inventory to
`~/.config/nixconf/work-ssh-extra.conf` (not committed). The file is appended
verbatim:

```sshconfig
Host rnsw-apigeon1 apigeon1
  HostName <apigeon1-ip>
  User alexis

Host rnsw-studio1 studio1
  HostName <studio1-ip>
  User alexis.pigeon
```

`rnsw-apigeon1` uses `alexis` because only that account currently has an
authorized key in `/etc/ssh/authorized_keys.d` (the YubiKey resident key). The
Windows studio workstation accepts `alexis.pigeon` (AD account).

`rnsw_server1` in the inventory resolves to the studio workstation's address.
It is kept for inventory parity; `rnsw-studio1`/`studio1` is the clearer alias.

### Copy keys to the fleet

Key distribution lives in `infra_management`, not here:
`playbooks/ssh-authorized-keys.yml` installs the controller's public keys on
both the Linux and Windows fleet, and one `-k` prompt is reused for the whole
run:

```bash
ansible-playbook playbooks/ssh-authorized-keys.yml -k
ansible-playbook playbooks/ssh-authorized-keys.yml -k -l tk2edcdxzci10
```

Windows accounts in the Administrators group are authorized through
`%ProgramData%\ssh\administrators_authorized_keys`, because sshd ignores the
user file for those accounts. The playbook writes both files and reports when
the admin file was skipped for lack of elevation.

The first connection to each host verifies its key in `~/.ssh/known_hosts`
(`StrictHostKeyChecking=ask`). Do not blanket-disable host-key checking on a
corporate network.

### Windows hosts: default shell

`sshd` starts cmd.exe unless the machine-wide default shell is set. Run this in
an elevated PowerShell once per Windows host, then reconnect:

```powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
  -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShellCommandOption `
  -Value "-c" -PropertyType String -Force
Restart-Service sshd
```

Use `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` when PowerShell
7 is not installed. The setting is machine-wide and also applies to
`ssh host '<command>'`, so POSIX-style one-liners must become PowerShell (or be
wrapped in `cmd /c`). Verify with `ssh studio1 '$PSVersionTable.PSVersion'`.

### Hardened client defaults

`Host *` sets, among others:

- `IdentitiesOnly=yes`, `IdentityAgent=none`, the software key and the YubiKey
  resident key (from `modules.yubikey`).
- `ControlMaster=auto`, `ControlPath=~/.ssh/cm/%C`, `ControlPersist=10m`:
  one handshake/touch, then reuse for 10 minutes.
- `ForwardAgent=no`, `ForwardX11=no`, `Compression=no`,
  `HashKnownHosts=yes`, `StrictHostKeyChecking=ask`, `UpdateHostKeys=yes`,
  `ConnectTimeout=10`, `ServerAliveInterval=30`.

`ssh -O exit <host>` drops a stale multiplexing master socket.

## Server side

`modules.ssh` (NixOS) enables OpenSSH with password and keyboard-interactive
auth disabled, root login disabled, and fail2ban. The rnsw desktop authorizes
only the YubiKey resident key for `alexis`; other hosts add their own keys
through `modules.users.authorizedKeys`.

## Why the fleet list is generated, not committed

`github.com/Alexyz205/nixconf` is public. Committing the inventory would expose
the internal CI/ML/service hostnames and addresses. The generator script is
generic; the inventory stays in the work checkout, and the generated fragment
lives under `~/.ssh/config.d` with mode `0600`.
