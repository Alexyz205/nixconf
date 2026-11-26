# Wake-on-LAN

`modules/system/wake-on-lan.nix` enables magic-packet wake on wired NICs.

- On systemd-networkd hosts it sets `WakeOnLan=magic` at link setup.
- On every host a one-shot `wake-on-lan.service` runs
  `ethtool -s <if> wol g` for each `en*` interface (or the configured list),
  and `wake-on-lan-before-sleep.service` reapplies it before every suspend.
- It is part of the `server`/`desktop` tiers, so the workstation and
  headless-worker get it; Proxmox/ISO do not.

This repo's choice:

- `headless-worker`: no LUKS, so WoL cold-boots it and SSH comes up.
- `workstation`: `modules.wakeOnLan.sleepState = "deep"` selects S3; the lock
  module suspends after 15 minutes idle, LUKS stays unlocked, and WoL resumes
  it. Verify `cat /sys/power/mem_sleep` shows `[deep]`; if the machine only
  offers `[s2idle]`, remove `sleepState` (WoL from s2idle is unreliable).
- `rnsw-apigeon1`: corporate desktop, `enp0s31f6`, hibernates as the primary
  sleep state (see below). The firmware exposes `GLAN S4` wake, so WoL from
  hibernation/power-off is the reliable path; `mem_sleep` only offers
  `[s2idle]`.

Verify on a running host:

```bash
sudo ethtool enp4s0 | grep -i wake
# Wake-on: g
```

## Firmware

Wake-on-LAN needs the NIC powered while the machine is off:

- Enable **Wake on LAN / Power On by PCI-E/PCI** in the UEFI/BIOS.
- Disable **ErP Ready / EuP / Deep Sleep** (they cut standby power to the NIC).
- Use the wired Ethernet port; Wi-Fi WoWLAN is a different, less reliable setup.

## Sending the packet

Get the target MAC on that machine:

```bash
ip link show enp4s0 | grep link/ether
```

From any host on the same LAN (the `wol` alias is `wakeonlan`):

```bash
wol aa:bb:cc:dd:ee:ff
wsw        # wake the home workstation
wsa        # wake rnsw-apigeon1 (corporate VLAN)
```

From a phone, a WoL app on the same VLAN. A magic packet is Ethernet
broadcast, so it does not cross routers or VLANs — and Tailscale is layer 3,
so it cannot carry WoL either: the sleeping machine has no tailnet presence to
tunnel to. From outside the LAN, run `wol` on an always-on tailnet peer that
sits on the same segment. Here that is the NAS (subnet router):

```bash
ssh nas 'wakeonlan d8:bb:c1:51:4f:f0'   # workstation MAC from config/network/lan.nix
```

The NAS wakes the target, the target boots, and then it is reachable again
through the NAS subnet route (`workstation.alexyz.org`) even though the
workstation itself is not a tailnet node. With the second router on `pve0`
(see [tailscale.md](tailscale.md)), waking does not depend on the NAS either:

```bash
ssh pve0 'wakeonlan d8:bb:c1:51:4f:f0'
```

Waking the _router_ host is the
exception: if the NAS is asleep there is no path left, so keep it on UPS and
never let it be the machine you wake remotely. WoL is unauthenticated: anyone
on that L2 segment can wake the machine, but it grants no access.

## LUKS: the important part

`headless-worker` has **no LUKS** (bare btrfs in the disko layout), so
Wake-on-LAN cold-boots it all the way to SSH.

`workstation` uses **LUKS + FIDO2/YubiKey**. WoL only powers it on; it then
stops at the initrd passphrase prompt. It does not bypass encryption. Options:

1. **Wake from suspend instead of poweroff.** `systemctl suspend` keeps the
   LUKS key in RAM; WoL wakes it and you can SSH in. Simplest, but test resume
   on the NVIDIA/niri setup, and treat suspended RAM as sensitive.
2. **initrd SSH (remote unlock).** `boot.initrd.network.enable = true` plus
   `boot.initrd.network.ssh` starts Dropbear in the initrd. SSH in, run
   `cryptsetup-askpass` / `systemd-tty-ask-password-agent`, enter the
   passphrase, and the normal boot continues. Needs:
   - a software SSH key authorized for initrd (a YubiKey key needs physical
     touch, which defeats remote unlock),
   - the NIC driver in the initrd (`igc` for the Intel I226-V),
   - DHCP (or a static address) before the root is mounted.
     The initrd shell is not behind the normal firewall; restrict it to the LAN
     and a dedicated key/port.
3. **TPM2 auto-unlock.** `systemd-cryptenroll --tpm2-device=auto` removes the
   prompt, but then the disk unlocks automatically on that machine. Without
   Secure Boot/PCR policy and a PIN this weakens at-rest protection.
4. **Tang/Clevis (NBDE).** Auto-unlock while on the LAN and fail closed when
   offline. Requires a Tang server (headless-worker or another always-on
   host), more moving parts than initrd SSH.

Do not add a TPM unlock or initrd SSH without deciding which trade-off you
want; each is a deliberate change to the boot security model.

## Corporate desktop: rnsw-apigeon1 (hibernate + TPM2)

`rnsw-apigeon1` is on the corporate `10.113.64.0/24` VLAN and is woken from
`RNSL-APIGEON5` with the `wsa` alias (MAC in `config/network/lan.nix`). The
Take2 VPN carries the broadcast on this setup; if a future VPN drops L2
broadcast, run `wsa` on an always-on host on that VLAN instead.

The desktop is configured around **hibernate**, not suspend:

- `Mod+Shift+X` hibernates immediately; `Mod+Ctrl+X` suspends for a short break.
- Idle: lock at 15 min, hibernate 45 min after the lock (60 min total).
- `hibernate.compressor=lz4` makes resume decompression faster than the LZO
  default; the image is written inside the LUKS container.
- The initrd gets the hibernate location from the `HibernateLocation` EFI
  variable (`boot.resumeDevice` is deliberately not set: a static `resume=`
  with offset 0 makes systemd refuse hibernation for a btrfs swapfile).

LUKS is unlocked in the initrd before the image resumes. For an unattended
remote wake, enroll the TPM2 keyslot (Secure Boot + PCR 7):

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
  /dev/disk/by-id/nvme-PC_SN810_NVMe_WDC_2048GB_21284T443808-part2
```

Keep the existing passphrase keyslot as recovery. Re-enroll after changing
Secure Boot keys/db or the firmware policy (PCR 7 changes). Anyone who can
power on the machine can then boot it; the disk remains encrypted if removed.
Confirm the policy allows TPM2 auto-unlock on a work device.

Verify after the rebuild/reboot:

```bash
busctl call org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager CanHibernate      # s "yes"
sudo ethtool enp0s31f6 | grep -i Wake-on          # Wake-on: g
sudo cryptsetup luksDump /dev/nvme0n1p2 | grep -i tpm2
```

Test once end-to-end: `systemctl hibernate`, send `wsa` from RNSL, and confirm
the machine powers on, unseals TPM2, and resumes the session.

## What people usually do

- **Unencrypted server** (headless-worker): WoL cold-boot; it reaches SSH on
  its own. This is the common homelab setup.
- **Encrypted desktop with YubiKey-only LUKS** (this workstation): suspend
  instead of powering off, then wake with WoL. LUKS stays unlocked, so there is
  no prompt and no extra keyslot. This is the usual answer when the disk is
  protected by a physical token.
- **Encrypted server**: initrd SSH plus a real passphrase keyslot; remote
  operators type the passphrase in the initrd. TPM2 auto-unlock is common on
  laptops with Secure Boot; Tang/Clevis is common in datacenters with an
  always-on key server.
- **Cold-booting a YubiKey-only desktop remotely** is uncommon because the
  FIDO2 keyslot needs the physical key. The alternatives are the recovery key
  at the initrd prompt, adding a passphrase keyslot, or TPM/Tang.

Check the workstation's keyslots before choosing:

```bash
sudo cryptsetup luksDump /dev/nvme0n1p2   # or the disk from `lsblk`
```

If only `systemd-fido2` and a recovery keyslot exist, add a passphrase slot
(`sudo cryptsetup luksAddKey ...`) before relying on initrd SSH.

## MAC table

Record the wired MACs here (or in your password manager) so any LAN host can
wake the machines:

| Host            | Interface   | MAC                 |
| --------------- | ----------- | ------------------- |
| workstation     | `enp4s0`    | `d8:bb:c1:51:4f:f0` |
| rnsw-apigeon1   | `enp0s31f6` | `4c:d7:17:a6:60:06` |
| headless-worker | `en*`       |                     |

These values also live in `config/network/lan.nix`, which feeds the
`Host workstation` SSH block (`192.168.1.100`) and the `wsw` alias
(`wsw` = `wakeonlan <workstation MAC>`) on every profile.
