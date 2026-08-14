#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-iso.sh [options]

Builds the installer-iso image and copies it to a Ventoy USB stick.

Options:
  -d, --dest-dir DIR  Ventoy mount point to copy the ISO into
                      (default: /media/alexis.pigeon/Ventoy)
  -e, --eject         Power off the USB device after copying and verifying
  -h, --help          Show this help message
EOF
}

ISO_BUILD=".#nixosConfigurations.installer-iso.config.system.build.isoImage"
DEST_DIR="/media/alexis.pigeon/Ventoy"
EJECT=0

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
}
trap cleanup EXIT

log() { printf '==> %s\n' "$*" >&2; }

cd "$SCRIPT_DIR"

log "Building ISO..."
nix build "$ISO_BUILD"

ISO_OUT="$(readlink -f result)"
ISO_SRC="$(find "$ISO_OUT" -name '*.iso' -type f | head -1)"
[ -n "$ISO_SRC" ] || { log "Error: no .iso found in $ISO_OUT" >&2; exit 1; }
ISO_NAME="$(basename "$ISO_SRC")"
DEST_ISO="$DEST_DIR/$ISO_NAME"

[ -d "$DEST_DIR" ] || { log "Error: $DEST_DIR not found (is the USB mounted?)" >&2; exit 1; }

DEV="$(findmnt -no SOURCE "$DEST_DIR")"
LABEL="$(findmnt -no LABEL "$DEST_DIR")"

is_ventoy() {
  [ -d "$DEST_DIR/.ventoy" ] && return 0
  [ "$LABEL" = "Ventoy" ] && return 0
  lsblk -no PARTLABEL "/dev/$(lsblk -no PKNAME "$DEV")" 2>/dev/null | grep -q "VTOYEFI" && return 0
  return 1
}

is_ventoy || { log "Error: $DEST_DIR is not a Ventoy USB (label: ${LABEL:-none})" >&2; exit 1; }

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