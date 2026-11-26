# Wake-on-LAN

`modules/system/wake-on-lan.nix` enables magic-packet wake on wired NICs.

- Naming an interface in `modules.wakeOnLan.interfaces` also makes NixOS emit a
  `40-<if>.link` with `WakeOnLan=magic`, applied by udev at link setup (the
  workstation does this for `enp4s0`).
- On every host a one-shot `wake-on-lan.service` runs
  `ethtool -s <if> wol g` for each `en*` interface (or the configured list),
  and `wake-on-lan-before-sleep.service` reapplies it before every suspend.
- It is part of the `server`/`desktop` tiers, so the workstation and
  headless-worker get it; Proxmox/ISO do not.

This repo's choice:

- `headless-worker`: no LUKS, so WoL cold-boots it and SSH comes up.
- `workstation`: `modules.wakeOnLan.sleepState = "deep"` selects S3 and the
  lock module suspends after 15 minutes idle. S3 WoL works with the MSI BIOS
  wake settings (see [Firmware](#firmware)); the stock `igc` driver is used,
  with no kernel patch. See "Workstation I225-V: what fixed WoL" below.
- `rnsw-apigeon1`: corporate desktop, `enp0s31f6`, hibernates as the primary
  sleep state (see below). The firmware exposes `GLAN S4` wake, so WoL from
  hibernation/power-off is the reliable path; `mem_sleep` only offers
  `[s2idle]`.

Verify on a running host:

```bash
cat /sys/power/mem_sleep                       # [deep] on the workstation
ls -l /etc/systemd/network/40-enp4s0.link      # WakeOnLan=magic
systemctl status wake-on-lan.service wake-on-lan-before-sleep.service
sudo ethtool enp4s0 | grep -i wake
# Wake-on: g
```

## Firmware

Wake-on-LAN needs the NIC powered while the machine is off:

- Enable **Wake on LAN / Power On by PCI-E/PCI** in the UEFI/BIOS.
- Disable **ErP Ready / EuP / Deep Sleep** (they cut standby power to the NIC).
- MSI Click BIOS: `Settings > Advanced > Wake Up Event Setup`:
  - `Wake Up Event By = BIOS` (not OS: BIOS mode activates the Resume items;
    OS mode lets the firmware clear `PME_Enable`).
  - `Resume By PCI-E Device = Enabled`.
  - `Resume By Onboard Intel LAN = Enabled` if present (enable `Network Stack`
    under `Advanced > Integrated Peripherals` first if the option is hidden).
  - `ErP Ready = Disabled` under `Power Management Setup`. `Max Power Saving`
    is not present on every BIOS version.
- This is the configuration that fixed the workstation's I225-V WoL. After a
  BIOS update, re-check these settings; A.10 -> AB2 also updates the Secure
  Boot keys, so lanzaboote may need re-enrollment.
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
ssh nas 'wakeonlan -i 192.168.1.255 d8:bb:c1:51:4f:f0'
```

Always pass `-i 192.168.1.255` on the NAS: `wakeonlan` defaults to the limited
broadcast `255.255.255.255`, which is only routable through a default route,
and the NAS has none (`ssh nas 'ip route get 255.255.255.255'` answers
`Network is unreachable`). The directed subnet broadcast matches the connected
route on `eno1` and is sent without a default gateway.

The NAS wakes the target, the target boots, and then it is reachable again
through the NAS subnet route (`workstation.alexyz.org`) even though the
workstation itself is not a tailnet node. With the second router on `pve0`
(see [tailscale.md](tailscale.md)), waking does not depend on the NAS either:

```bash
ssh pve0 'wakeonlan -i 192.168.1.255 d8:bb:c1:51:4f:f0'
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
   - the NIC driver in the initrd (`igc` for the Intel I225-V),
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

## Workstation I225-V: what fixed WoL

S3 WoL on the workstation's onboard Intel I225-V (`8086:15f3`, rev 03) works
with the MSI BIOS wake settings under [Firmware](#firmware); the stock `igc`
driver is used, with no kernel patch.

What did **not** fix it (all tested on this host):

- The I226 `PHPM` D3 link-disable bug does not apply here: at suspend this
  unit reports `PHPM=0x00044080`; `DIS_100_D3`, `DIS_1000_D3` and
  `DIS_2500_D3` are not set, so clearing `DIS_100_D3` in the driver was a
  no-op.
- Forcing 10M or 100M before suspend kept the link up and the NIC counted the
  magic packet, but the system still did not resume.
- The OS side was already correct: `Wake-on: g`,
  `/sys/class/net/enp4s0/device/power/wakeup=enabled`, `/proc/acpi/wakeup`
  NIC/root port enabled, and packets reached the NIC while awake.
- The NAS sender was fixed separately: it has no default route, so use
  `wakeonlan -i 192.168.1.255 ...`.

The missing piece was the BIOS wake configuration (details under
[Firmware](#firmware)):

- `Wake Up Event By = BIOS` (not OS; OS mode lets the firmware clear
  `PME_Enable`).
- `Resume By PCI-E Device = Enabled`.
- `Resume By Onboard Intel LAN = Enabled` if present (enable `Network Stack`
  first if hidden).
- `ErP Ready = Disabled`.

Verify with `ssh nas cat /tmp/wol-ping.log` (`result=0`) or ping
`192.168.1.100` after the packet. The screen may stay black while the machine
is awake; a key wakes the display.

## What people usually do

- **Unencrypted server** (headless-worker): WoL cold-boot; it reaches SSH on
  its own. This is the common homelab setup.
- **Encrypted desktop with YubiKey-only LUKS** (this workstation): suspend
  instead of powering off and wake with WoL; the BIOS wake settings above keep
  the I225-V usable from S3. LUKS stays unlocked while suspended, so there is
  no prompt.
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
