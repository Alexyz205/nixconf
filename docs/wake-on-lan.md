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
```

From a phone, a WoL app on the same VLAN. A magic packet is Ethernet
broadcast, so it does not cross routers or VLANs; from outside the LAN, run
`wol` on an always-on LAN host (headless-worker) or configure the router's WoL
forwarding (UDP 9 to the broadcast address). WoL is unauthenticated: anyone on
that L2 segment can wake the machine, but it grants no access.

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

| Host            | Interface | MAC                 |
| --------------- | --------- | ------------------- |
| workstation     | `enp4s0`  | `d8:bb:c1:51:4f:f0` |
| headless-worker | `en*`     |                     |

These values also live in `config/network/lan.nix`, which feeds the
`Host workstation` SSH block (`192.168.1.100`) and the `wsw` alias
(`wsw` = `wakeonlan <workstation MAC>`) on every profile.
