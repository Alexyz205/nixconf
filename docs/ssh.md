# SSH

`modules/system/ssh.nix` owns the client config (`~/.ssh/config`) and the
key-only OpenSSH server. Personal/LAN hosts are declared there. The corporate
fleet, its inventory and its `ssh-copy-id`/Ansible workflow live in the private
work repository.

## Keys

- `~/.ssh/id_ed25519` is the primary software key.
- The personal YubiKey resident key (`id_ed25519_sk_rk_alexis-perso`) is
  appended by `modules/system/yubikey.nix`. Only the `.pub` is tracked; the
  private handle is downloaded on each machine with:

  ```bash
  cd ~/.ssh && ssh-keygen -K
  ```

- `Host *` sets `IdentitiesOnly=yes`, `IdentityAgent=none`, and a 10-minute
  `ControlMaster` socket, so one key touch covers a burst of connections.
- `ssh -O exit <host>` drops a stale multiplexing master.

## Personal hosts

The workstation, NAS and Proxmox aliases are declared in
`modules/system/ssh.nix`; use `ssh-copy-id -i ~/.ssh/id_ed25519.pub <host>` to
authorize the software key.

## Windows hosts: default shell

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
wrapped in `cmd /c`).

## Server side

`modules.ssh` (NixOS) enables OpenSSH with password and keyboard-interactive
auth disabled, root login disabled, and fail2ban. Hosts authorize the personal
YubiKey resident key for `alexis`; other hosts add their own keys through
`modules.users.authorizedKeys`.
