# Secure Boot (lanzaboote)

`modules/system/secure-boot.nix` brings in
[lanzaboote](https://github.com/nix-community/lanzaboote), which signs the
kernel/initrd and installs signed Unified Kernel Images, replacing systemd-boot
as the boot manager. It is **off by default**: enabling it without a working
key enrollment can make the machine unbootable.

## Prerequisites

- UEFI firmware with Secure Boot, and a BIOS/UEFI password (otherwise an
  attacker can just turn Secure Boot off).
- A recovery path: a second bootable USB (the nixconf installer works) and/or
  the ability to clear Secure Boot keys in firmware setup.
- The ESP from the disko layout is already 1 GiB, enough for the default
  `configurationLimit = 10` (lanzaboote inherits it from systemd-boot).

## Automated enrollment (recommended)

Add to the host module (`workstation` or `headless-worker`):

```nix
modules.secureBoot = {
  enable = true;
  autoGenerateKeys = true;   # sbctl create-keys on first boot
  autoEnrollKeys = true;     # writes PK/KEK/db.auth to the ESP
};
```

Then:

```bash
nrb                                 # build first, keep the current generation bootable
nro                                 # nh os boot: make the new generation the boot default
sudo reboot
```

On the next boot systemd-boot enrolls the keys (`secure-boot-enroll force`).
If the firmware is in "setup mode" this is silent; otherwise it prompts or
requires the existing admin key. After the reboot:

```bash
sbctl status          # Secure Boot: enabled, Setup Mode: disabled
sbctl verify          # every boot artifact signed
bootctl status        # lanzaboote entries + secure boot state
```

Back up `/var/lib/sbctl` (keys + GUID) offline immediately. Losing it means
re-enrolling keys (or resetting firmware keys) before the next kernel update.

## Manual enrollment (if auto is not possible)

```bash
sudo sbctl create-keys
sudo sbctl enroll-keys -m        # -m includes Microsoft's option-ROM keys
nro && sudo reboot
```

## Recovery

1. Enter firmware setup, disable Secure Boot (or delete the enrolled keys).
2. Boot the previous generation from the boot menu, or the installer USB.
3. Fix the config (`modules.secureBoot.enable = false`) and rebuild.
4. Re-enroll only after `sbctl status` and `sbctl verify` are clean.

Do not enable `autoEnrollKeys.allowBrickingMyMachine`: it skips option-ROM
signature checks and can leave the GPU/NIC firmware unbootable.

## Not enabled here

Measured boot / TPM-bound LUKS (`boot.lanzaboote.measuredBoot`,
`systemd-cryptenroll`) is deliberately left out: it needs a PCR policy that is
tested against every kernel update, plus a recovery key. It can be layered on
later once Secure Boot itself is stable.
