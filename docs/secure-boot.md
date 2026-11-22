# Secure Boot (lanzaboote)

`modules/system/secure-boot.nix` brings in
[lanzaboote](https://github.com/nix-community/lanzaboote). It replaces
systemd-boot with lanzaboote's signed loader and installs one signed Unified
Kernel Image (UKI) per generation under `/boot/EFI/Linux`, keeping the kernel
and initrd in `/boot/EFI/nixos`.

It is **off by default** (`optInNames` in `modules/flake/nixos.nix`). Currently
enabled on `workstation` only, with manual key enrollment.

Enabling it without keys makes `nixos-rebuild` fail rather than install
unsigned artifacts (`installUnsigned` defaults to `autoGenerateKeys.enable`).

## Trust model

- Firmware `db` holds the owner key + Microsoft OEM certificates. The
  Microsoft ones are **required** on the workstation: the RTX 5070 UEFI Option
  ROM is signed by Microsoft, and without it the machine has no display.
- Firmware launches `/EFI/BOOT/BOOTX64.EFI` (signed), which is lanzaboote's
  systemd-boot, then the generation's UKI from `/EFI/Linux` (signed).
- The UKI embeds the SHA-256 of its kernel and initrd, and the stub rejects a
  mismatch regardless of Secure Boot state (lanzaboote >= 1.1). The files in
  `/EFI/nixos` therefore do **not** need their own signature; `sbctl verify`
  reports them as unsigned and that is expected.
- Secure Boot verifies EFI boot artifacts, not kernel modules. The NVIDIA
  driver is unaffected (NixOS does not enable kernel lockdown by default).

## Prerequisites

- UEFI firmware, booting via systemd-boot before the switch
  (`bootctl status`: `Firmware: UEFI`, `Current Boot Loader: systemd-boot`).
- A firmware **admin/supervisor password**. Without it anyone can disable
  Secure Boot, and the protection is cosmetic.
- A recovery path: the installer ISO (`scripts/build-iso.sh`) and/or the
  admin password to disable Secure Boot in firmware.
- The disko ESP is 1 GiB. A kernel+initrd pair is ~45 MB, so
  `configurationLimit = 10` uses ~450 MB. Lower it in
  `modules/system/boot.nix` if `/boot` gets tight.

## Manual enrollment (workstation)

Order matters: create the keys **before** the first lanzaboote switch.

```nix
modules.secureBoot = {
  enable = true;
  # pkiBundle defaults to /var/lib/sbctl, bind-mounted from /persistent.
};
```

1. Build a recovery ISO first: `sudo ./scripts/build-iso.sh -e`.
2. Create the keys (they land in `/var/lib/sbctl`, persisted):

   ```bash
   sudo nix shell nixpkgs#sbctl -c sbctl create-keys
   findmnt /var/lib/sbctl
   ```

3. Enable the module, then build and switch:

   ```bash
   nrb && nr
   sudo sbctl verify        # UKIs + loaders signed
   ```

   The machine still boots normally: the firmware is not enforcing anything.

4. Remove the pre-lanzaboote boot entries. They are legacy systemd-boot
   `.conf` files pointing at `/nix/store/.../bzImage`, which the firmware will
   refuse once keys are enrolled. zsh expands globs as the calling user and
   `/boot` is `0700 root`, so the glob must run in a root shell:

   ```bash
   sudo sh -c 'rm -f /boot/loader/entries/*.conf'
   sudo sh -c 'ls -A /boot/loader/entries'    # empty
   ```

5. Reboot and confirm the machine boots a UKI. **This is the gate for
   enrollment:**

   ```bash
   sudo bootctl status | grep -i 'current entry'
   # Current Entry: nixos-generation-148-<hash>.efi
   ```

   You can stop here indefinitely; nothing is enforced and rebuilds work.

6. Firmware (MSI MPG Z590 GAMING PLUS, AMI A.10):
   - set the administrator password;
   - `Settings -> Security -> Secure Boot`: **Secure Boot = Enabled**,
     **Secure Boot Mode = Custom**;
   - **Delete all Secure Boot key databases** -> Yes. This is what produces
     Setup Mode. Do not use "Restore Factory Keys".
   - Disable Fast Boot if you want the recovery USB to stay bootable.
7. Boot back and enroll:

   ```bash
   sudo sbctl status        # Setup Mode: Enabled, Vendor Keys: none
   sudo sbctl enroll-keys --microsoft
   sudo sbctl status        # Vendor Keys: microsoft (PK applies at next boot)
   ```

8. Reboot. Setup Mode only flips after the next firmware init (sbctl
   documentation), so the pre-reboot status is not meaningful.

## Verification

```bash
sudo sbctl status
# Installed:      ✓ sbctl is installed
# Owner GUID:     ...
# Setup Mode:     ✓ Disabled
# Secure Boot:    ✓ Enabled
# Vendor Keys:    microsoft

sudo bootctl status | grep -Ei 'secure boot|current entry'
# Secure Boot: enabled (user)
# Current Entry: nixos-generation-148-<hash>.efi

sudo sbctl verify
```

`sbctl verify` must show `✓` for `/boot/EFI/BOOT/BOOTX64.EFI`,
`/boot/EFI/systemd/systemd-bootx64.efi` and every UKI. The `✗` lines for
`/boot/EFI/nixos/kernel-*.efi` and `systemd-boot-fallbackx64.efi` are expected
(see trust model above).

After every later `nh os switch`, lanzaboote signs the new generation with the
same key; no extra step.

## Automated provisioning (headless hosts)

For a host without console access, let lanzaboote provision itself:

```nix
modules.secureBoot = {
  enable = true;
  autoGenerateKeys = true;
  autoEnrollKeys = true;
};
boot.lanzaboote.autoEnrollKeys.autoReboot = true;  # optional
```

This is trust-on-first-use: the first boot installs unsigned artifacts, a
systemd service generates the keys and re-signs everything, and systemd-boot
enrolls the keys on the following boot. Note that
`boot.lanzaboote.autoEnrollKeys.autoReboot` is set directly because the module
does not expose it.

## Maintenance

- **BIOS updates reset the key databases.** Expect to re-run step 7 (or
  disable Secure Boot until you can).
- **Back up the keys offline**; losing `/var/lib/sbctl` means the next kernel
  build produces artifacts the firmware rejects:

  ```bash
  sudo tar -C /var/lib/sbctl -czf /tmp/sbctl-$(date +%F).tar.gz .
  ```

  The archive contains private keys: keep it on encrypted/offline media, not
  only on the machine itself.

- **Reverting:** set `modules.secureBoot.enable = false` and rebuild only
  while enforcement is off. While Secure Boot is on, the plain systemd-boot is
  unsigned and will not boot, so disable Secure Boot in firmware first.

## Recovery

1. Firmware setup: set Secure Boot to `Disabled` (or delete the key databases).
2. Boot the previous UKI from the boot menu, or the installer USB.
3. Fix the configuration (`modules.secureBoot.enable = false` if needed) and
   rebuild.
4. Re-enroll only after `sbctl status`/`sbctl verify` are clean.

## Not enabled here

Measured boot / TPM-bound LUKS (`boot.lanzaboote.measuredBoot`,
`systemd-cryptenroll`) is deliberately left out: it needs a PCR policy tested
against every kernel update plus a recovery key. It can be layered on once
Secure Boot itself is stable.
