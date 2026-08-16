#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-iso.sh [options]

Builds the installer-iso image and copies it to a Ventoy USB stick.

Options:
  -d, --dest-dir DIR  Ventoy mount point to copy the ISO into
                      (default: auto-detect a plugged-in Ventoy USB)
  -e, --eject         Power off the USB device after copying and verifying
  -h, --help          Show this help message
EOF
}

ISO_BUILD=".#nixosConfigurations.installer-iso.config.system.build.isoImage"
DEST_DIR=""
EJECT=0
MOUNTED_BY_US=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dest-dir) DEST_DIR="$2"; shift ;;
    -e|--eject)   EJECT=1 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)            echo "Unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cleanup() {
  rm -f "$SCRIPT_DIR/result" "$SCRIPT_DIR/.sha256.src" "$SCRIPT_DIR/.sha256.dst"
  if [ "$MOUNTED_BY_US" = "1" ] && [ -n "${DEST_DIR:-}" ] &&
     [ "${EJECT:-0}" != "1" ]; then
    umount "$DEST_DIR" 2>/dev/null || true
    rmdir "$DEST_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

log() { printf '==> %s\n' "$*" >&2; }

is_ventoy_mount() {
  local mnt="$1" label="$2" dev="$3"
  [ -d "$mnt/.ventoy" ] && return 0
  [ "$label" = "Ventoy" ] && return 0
  local parent partlabel
  parent="$(lsblk -no PKNAME "$dev" 2>/dev/null || true)"
  if [ -n "$parent" ]; then
    partlabel="$(lsblk -no PARTLABEL "$parent" 2>/dev/null || true)"
    [[ "$partlabel" == *VTOYEFI* ]] && return 0
  fi
  return 1
}

find_ventoy_mount() {
  local target source label tran
  while IFS= read -r target source label; do
    [ -d "$target" ] || continue
    [[ "$source" == /dev/* ]] || continue
    tran="$(lsblk -no TRAN "$source" 2>/dev/null || true)"
    [ "$tran" = "usb" ] || continue
    if is_ventoy_mount "$target" "$label" "$source"; then
      printf '%s\n' "$target"
      return 0
    fi
  done < <(findmnt -rno TARGET,SOURCE,LABEL)
  return 1
}

# Identify the Ventoy data partition (LABEL=Ventoy) on the plugged-in USB key.
find_ventoy_part() {
  local disk part label
  while IFS= read -r disk; do
    trans="$(lsblk -no TRAN "/dev/$disk" 2>/dev/null || true)"
    [ "$trans" = "usb" ] || continue
    while IFS= read -r part; do
      label="$(lsblk -no LABEL "/dev/$part" 2>/dev/null || true)"
      if [ "$label" = "Ventoy" ]; then
        printf '%s\n' "/dev/$part"
        return 0
      fi
    done < <(lsblk -nlo NAME "/dev/$disk")
  done < <(lsblk -dno NAME)
  return 1
}

# Mount the Ventoy partition of the plugged-in USB key if not already mounted.
mount_ventoy_usb() {
  local part mp mountpoint
  part="$(find_ventoy_part)" || return 1
  if mp="$(findmnt -no TARGET "$part" 2>/dev/null)"; then
    printf '%s\n' "$mp"
    return 0
  fi
  mountpoint="$(mktemp -d "${TMPDIR:-/tmp}/ventoy.XXXXXX")"

  if command -v udisksctl >/dev/null 2>&1; then
    if udisksctl mount -b "$part" --no-block >/dev/null 2>&1; then
      mp="$(findmnt -no TARGET "$part" 2>/dev/null || true)"
      rmdir "$mountpoint" 2>/dev/null || true
    fi
  elif command -v systemd-mount >/dev/null 2>&1; then
    if timeout 30 systemd-mount --no-block --collect "$part" "$mountpoint" >/dev/null 2>&1; then
      mp="$(findmnt -no TARGET "$part" 2>/dev/null || true)"
      if [ -z "$mp" ]; then
        umount "$mountpoint" 2>/dev/null || true
        rmdir "$mountpoint" 2>/dev/null || true
      fi
    else
      rmdir "$mountpoint" 2>/dev/null || true
    fi
  fi

  if [ -z "$mp" ]; then
    rmdir "$mountpoint" 2>/dev/null || true
    log "Error: could not auto-mount $part (no udisksctl/polkit and no passwordless sudo)." >&2
    log "Mount it yourself and re-run, or run with root, or use -d DIR:" >&2
    log "  sudo mount $part /mnt/ventoy" >&2
    return 1
  fi
  MOUNTED_BY_US=1
  printf '%s\n' "$mp"
}

cd "$SCRIPT_DIR"

log "Building ISO..."
nix build "$ISO_BUILD"

ISO_OUT="$(readlink -f result)"
ISO_SRC="$(find "$ISO_OUT" -name '*.iso' -type f | head -1)"
[ -n "$ISO_SRC" ] || { log "Error: no .iso found in $ISO_OUT" >&2; exit 1; }
ISO_NAME="$(basename "$ISO_SRC")"

if [ -z "$DEST_DIR" ]; then
  if DEST_DIR="$(find_ventoy_mount)"; then
    log "Ventoy USB detected at $DEST_DIR"
  elif DEST_DIR="$(mount_ventoy_usb)"; then
    log "Ventoy USB mounted at $DEST_DIR"
  else
    log "Error: no Ventoy USB detected. Plug one in or use -d DIR." >&2
    exit 1
  fi
fi

DEST_ISO="$DEST_DIR/$ISO_NAME"

[ -d "$DEST_DIR" ] || { log "Error: $DEST_DIR not found (is the USB mounted?)" >&2; exit 1; }

DEV="$(findmnt -no SOURCE "$DEST_DIR")"
LABEL="$(findmnt -no LABEL "$DEST_DIR")"

is_ventoy_mount "$DEST_DIR" "$LABEL" "$DEV" ||
  { log "Error: $DEST_DIR is not a Ventoy USB (label: ${LABEL:-none})" >&2; exit 1; }

log "Source:     $ISO_SRC"

log "Copying $ISO_NAME -> $DEST_ISO..."
cp --reflink=never "$ISO_SRC" "$DEST_ISO"

log "Computing checksums..."
sha256sum "$ISO_SRC" > .sha256.src
sha256sum "$DEST_ISO" > .sha256.dst

SRC_SUM="$(awk '{print $1}' .sha256.src)"
DST_SUM="$(awk '{print $1}' .sha256.dst)"

log "Source:     $SRC_SUM"
log "Dest:       $DST_SUM"

if [ "$SRC_SUM" = "$DST_SUM" ]; then
  log "Checksums MATCH - copy verified."
else
  log "Checksums MISMATCH - copy corrupted." >&2
  exit 1
fi

if [ "$EJECT" = "1" ]; then
  log "Ejecting USB..."
  log "Flushing buffers (sync)..."
  if ! timeout 60 sync; then
    log "Warning: sync timed out (slow/busy device?), continuing" >&2
  fi
  DISK="/dev/$(lsblk -no PKNAME "$DEV")"

  UNMOUNTED=0
  for i in 1 2 3; do
    if timeout 10 udisksctl unmount -b "$DEV" 2>/dev/null; then
      UNMOUNTED=1
      break
    fi
    log "Unmount attempt $i failed, retrying in 2s..."
    sleep 2
  done

  if [ "$UNMOUNTED" = "0" ]; then
    log "Warning: could not unmount $DEV" >&2
    pgrep -f "nautilus .*$DEV" >/dev/null 2>&1 && log "Note: a file manager is using $DEV; close it if unmount keeps failing"
  fi

  log "Powering off $DISK..."
  if timeout 20 udisksctl power-off -b "$DISK"; then
    log "USB ejected."
  else
    log "Warning: power-off timed out or failed" >&2
  fi
fi