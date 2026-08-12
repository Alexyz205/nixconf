#!/usr/bin/env bash
set -eu

HOST="workstation"

# Locate the flake: on the live ISO the filesystem root is at /iso,
# otherwise assume /etc/nixos/flake (installed system testing).
if grep -q 'VARIANT_ID=installer' /etc/os-release 2>/dev/null && [[ -d /iso/etc/nixos/flake ]]; then
  FLAKE=/iso/etc/nixos/flake
elif [[ -d /etc/nixos/flake ]]; then
  FLAKE=/etc/nixos/flake
else
  echo "Error: flake not found. Make sure you booted the workstation ISO." >&2
  exit 1
fi

echo "Scanning available disks..."
mapfile -t DISKS < <(
  lsblk -dno NAME,SIZE,TYPE 2>/dev/null \
    | awk '$3 == "disk" {print $1, $2}' \
    | sort
)
if [[ ${#DISKS[@]} -eq 0 ]]; then echo "No disks found." >&2; exit 1; fi

echo
echo "Available disks:"
echo "----------------"
TOTAL=${#DISKS[@]}
for idx in $(seq 0 $(( TOTAL - 1 ))); do
  printf "  %2d) %s\n" $(( idx + 1 )) "${DISKS[$idx]}"
done
echo

while true; do
  read -rp "Select disk number [1-$TOTAL]: " CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= TOTAL )); then
    IDX=$(( CHOICE - 1 ))
    SELECTED_NAME=$(echo "${DISKS[$IDX]}" | awk '{print $1}')
    break
  fi
  echo "Invalid selection."
done

BY_ID=$(find /dev/disk/by-id -maxdepth 1 -type l -lname "*/$SELECTED_NAME" 2>/dev/null \
  | grep -v -- '-part[0-9]' | head -n1 || true)

if [[ -z "$BY_ID" ]]; then
  BY_ID="/dev/$SELECTED_NAME"
  echo "No /dev/disk/by-id alias - using $BY_ID (may change across reboots)."
else
  echo "Disk resolved to: $BY_ID"
fi
echo

echo "!!! DESTRUCTIVE - this will ERASE ALL DATA on $BY_ID !!!"
read -rp 'Type "yes" to continue: ' CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then echo "Aborting."; exit 1; fi
echo

echo "Plug in your YubiKey - disko will ask you to touch it during enrollment."
echo
sudo env PATH="$PATH" nix run \
  --extra-experimental-features 'nix-command flakes' \
  'github:nix-community/disko/master#disko-install' -- \
  --flake "$FLAKE#$HOST" \
  --disk main "$BY_ID" \
  --write-efi-boot-entries

echo
echo "Done. Remove the USB key and run:  sudo reboot"
