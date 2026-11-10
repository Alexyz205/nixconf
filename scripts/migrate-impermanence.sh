#!/usr/bin/env bash
set -euo pipefail

# Prepare an existing (pre-impermanence) NixOS install for the tmpfs-root
# layout: create the /persistent btrfs subvolume, mount it and copy the system
# state the new configuration expects to persist into it.
#
# It never formats, resizes or moves anything: the old /root subvolume stays
# mounted at / until the next boot, so the previous generation in the boot
# menu remains a working rollback target.
#
# See docs/impermanence.md for the reasoning and the post-reboot checks.

SCRIPT_NAME=${0##*/}
PERSISTENT_DIR=/persistent
DEVICE=""
DRY_RUN=0
ASSUME_YES=0
COPY_LOG=1
TARGET_USER=alexis
TOPLEVEL_MOUNT=""
MOUNTED_BY_US=0

usage() {
  cat <<'EOF'
Usage: migrate-impermanence.sh [options]

Prepares the running NixOS system for modules.impermanence:
  1. creates the btrfs subvolume mounted at /persistent
  2. mounts it at /persistent
  3. copies the current machine state into it (ssh host keys, machine-id,
     the password hash for hashedPasswordFile, NetworkManager, bluetooth,
     containers, systemd state, logs)
  4. verifies the copies

Nothing is reformatted; / stays on its current subvolume until the next boot.

Options:
  -d, --device DEV       btrfs device holding the root filesystem
                         (default: the device currently mounted at /)
  -p, --persistent DIR   persistent mount point (default: /persistent)
      --skip-log         do not copy /var/log (can be several GiB)
  -u, --user NAME        account whose password hash is extracted from
                         /etc/shadow (default: alexis)
  -n, --dry-run          show what would be done, change nothing
  -y, --yes              do not ask for confirmation
  -h, --help             show this help

Run it as root:  sudo ./scripts/migrate-impermanence.sh
EOF
}

log() { printf '==> %s\n' "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n ${TOPLEVEL_MOUNT} ]] && findmnt -no TARGET "${TOPLEVEL_MOUNT}" >/dev/null 2>&1; then
    umount "${TOPLEVEL_MOUNT}" 2>/dev/null || true
  fi
  if [[ -n ${TOPLEVEL_MOUNT} ]]; then
    rmdir "${TOPLEVEL_MOUNT}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
  -d | --device)
    DEVICE="$2"
    shift
    ;;
  -p | --persistent)
    PERSISTENT_DIR="$2"
    shift
    ;;
  --skip-log) COPY_LOG=0 ;;
  -u | --user)
    TARGET_USER="$2"
    shift
    ;;
  -n | --dry-run) DRY_RUN=1 ;;
  -y | --yes) ASSUME_YES=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  *)
    echo "Unexpected argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

if [[ ${DRY_RUN} -eq 0 ]]; then
  [[ ${EUID} -eq 0 ]] || die "must run as root (sudo ./scripts/${SCRIPT_NAME})"
fi
for dep in btrfs findmnt mount umount install cp awk lsblk; do
  command -v "${dep}" >/dev/null 2>&1 || die "missing dependency: ${dep}"
done

# --- preflight -------------------------------------------------------------

root_fstype=$(findmnt -no FSTYPE /)
[[ ${root_fstype} == btrfs || ${root_fstype} == tmpfs ]] ||
  die "/ is ${root_fstype}, expected btrfs (pre-migration) or tmpfs (already migrated)"

if [[ ${root_fstype} == tmpfs ]]; then
  if findmnt -no TARGET "${PERSISTENT_DIR}" >/dev/null 2>&1; then
    log "/ is tmpfs and ${PERSISTENT_DIR} is mounted: already migrated, nothing to do"
    exit 0
  fi
  die "/ is tmpfs but ${PERSISTENT_DIR} is not mounted; boot a previous generation or the ISO and re-run"
fi

if [[ -z ${DEVICE} ]]; then
  DEVICE=$(findmnt -no SOURCE /)
fi
# findmnt appends the subvolume for non-top-level mounts, e.g.
# /dev/mapper/crypted[/root]; the block device is the part before the bracket.
DEVICE=${DEVICE%%\[*}
[[ -n ${DEVICE} ]] || die "could not detect the device backing /"
[[ -b ${DEVICE} ]] || die "${DEVICE} is not a block device"
device_fstype=$(lsblk -no FSTYPE "${DEVICE}" | head -n1)
[[ ${device_fstype} == btrfs ]] ||
  die "${DEVICE} is ${device_fstype:-unknown}, expected btrfs"

if findmnt -no TARGET "${PERSISTENT_DIR}" >/dev/null 2>&1; then
  log "${PERSISTENT_DIR} is already a mount, keeping it"
fi

cat >&2 <<EOF

Plan:
  device            : ${DEVICE}
  subvolume         : /persistent
  mount point       : ${PERSISTENT_DIR}
  copy /var/log     : $([[ ${COPY_LOG} -eq 1 ]] && echo yes || echo no)
  dry run           : $([[ ${DRY_RUN} -eq 1 ]] && echo yes || echo no)

The current / stays untouched until the next boot. If anything goes wrong,
boot the previous generation from the systemd-boot menu.
EOF

if [[ ${DRY_RUN} -eq 0 && ${ASSUME_YES} -eq 0 ]]; then
  answer=""
  read -r -p "Proceed? [y/N] " answer || true
  if [[ ${answer} != y && ${answer} != Y ]]; then
    log "aborted"
    exit 1
  fi
fi

run() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    printf '  [dry-run] %s\n' "$*" >&2
  else
    "$@"
  fi
}

# --- subvolume -------------------------------------------------------------

if [[ ${DRY_RUN} -eq 1 ]]; then
  log "dry-run: would mount ${DEVICE} (subvolid=5) and create subvolume 'persistent' when missing"
else
  TOPLEVEL_MOUNT=$(mktemp -d /run/migrate-impermanence.XXXXXX)
  log "inspecting ${DEVICE} from its btrfs top level"
  mount -o subvolid=5 "${DEVICE}" "${TOPLEVEL_MOUNT}"

  subvol_exists=0
  if btrfs subvolume list "${TOPLEVEL_MOUNT}" | awk '{print $NF}' | grep -qx persistent; then
    subvol_exists=1
  fi

  if [[ ${subvol_exists} -eq 1 ]]; then
    log "subvolume 'persistent' already exists"
  else
    log "creating subvolume 'persistent'"
    btrfs subvolume create "${TOPLEVEL_MOUNT}/persistent"
  fi

  umount "${TOPLEVEL_MOUNT}"
  rmdir "${TOPLEVEL_MOUNT}"
  TOPLEVEL_MOUNT=""
fi

# --- mount -----------------------------------------------------------------

if findmnt -no TARGET "${PERSISTENT_DIR}" >/dev/null 2>&1; then
  log "${PERSISTENT_DIR} already mounted, reusing it"
elif [[ ${DRY_RUN} -eq 1 ]]; then
  log "dry-run: mount -o subvol=/persistent,compress=zstd,noatime ${DEVICE} ${PERSISTENT_DIR}"
else
  install -d -m 0755 "${PERSISTENT_DIR}"
  if findmnt -no TARGET "${PERSISTENT_DIR}" >/dev/null 2>&1; then
    log "${PERSISTENT_DIR} is mounted, reusing it"
  else
    log "mounting ${DEVICE} (subvol=/persistent) at ${PERSISTENT_DIR}"
    mount -o subvol=/persistent,compress=zstd,noatime "${DEVICE}" "${PERSISTENT_DIR}"
    MOUNTED_BY_US=1
  fi
fi

if [[ ${DRY_RUN} -eq 0 ]] && ! findmnt -no TARGET "${PERSISTENT_DIR}" >/dev/null 2>&1; then
  die "${PERSISTENT_DIR} is not a mount after mounting"
fi

# --- seed ------------------------------------------------------------------

seed() {
  local src="$1" dest_dir="$2"
  if [[ ! -e ${src} ]]; then
    warn "skip ${src} (does not exist on this system)"
    return 0
  fi
  if [[ ${DRY_RUN} -eq 1 ]]; then
    printf '  [dry-run] cp -a --reflink=auto %s -> %s/%s\n' "${src}" "${PERSISTENT_DIR}" "${dest_dir}" >&2
    return 0
  fi
  install -d -m 0755 "${PERSISTENT_DIR}/${dest_dir}"
  if ! cp -a --reflink=auto "${src}" "${PERSISTENT_DIR}/${dest_dir}/"; then
    warn "partial copy of ${src} (live service writing to it?)"
  fi
}

log "copying machine state into ${PERSISTENT_DIR}"
seed /etc/ssh etc
seed /etc/machine-id etc
seed /etc/shadow etc
seed /etc/NetworkManager/system-connections etc/NetworkManager
seed /var/lib/nixos var/lib
seed /var/lib/NetworkManager var/lib
seed /var/lib/bluetooth var/lib
seed /var/lib/containers var/lib
seed /var/lib/sbctl var/lib
seed /var/lib/systemd var/lib
if [[ ${COPY_LOG} -eq 1 ]]; then
  seed /var/log var
else
  log "skipping /var/log (--skip-log)"
fi

# /etc/shadow cannot be persisted through impermanence (the users activation
# script writes it before the persistence script runs, which then refuses to
# replace a non-empty file), so the password hash is kept as its own file that
# users.users.*.hashedPasswordFile reads on every activation.
hash_file="${PERSISTENT_DIR}/etc/${TARGET_USER}.hash"
if [[ ${DRY_RUN} -eq 1 ]]; then
  log "dry-run: extract the ${TARGET_USER} password hash from /etc/shadow into ${hash_file}"
else
  log "extracting the ${TARGET_USER} password hash into ${hash_file}"
  user_hash=$(awk -F: -v u="${TARGET_USER}" '$1 == u { print $2; exit }' "${PERSISTENT_DIR}/etc/shadow" 2>/dev/null || true)
  if [[ -z ${user_hash} || ${user_hash} == "!"* || ${user_hash} == "*" ]]; then
    warn "no usable password hash for ${TARGET_USER}; login and sudo stay locked until ${hash_file} holds one"
  else
    install -m 0600 /dev/null "${hash_file}"
    printf '%s\n' "${user_hash}" >"${hash_file}"
  fi
fi

# --- verify ----------------------------------------------------------------

if [[ ${DRY_RUN} -eq 1 ]]; then
  log "dry run complete, nothing was changed"
  exit 0
fi

[[ -s ${PERSISTENT_DIR}/etc/shadow ]] ||
  die "${PERSISTENT_DIR}/etc/shadow is missing or empty; without it login and sudo would break"
[[ -s ${PERSISTENT_DIR}/etc/machine-id ]] ||
  die "${PERSISTENT_DIR}/etc/machine-id is missing or empty"
compgen -G "${PERSISTENT_DIR}/etc/ssh/ssh_host_*_key" >/dev/null ||
  die "${PERSISTENT_DIR}/etc/ssh has no host keys; SSH clients would see a new host identity"
if [[ ! -s ${hash_file} ]]; then
  warn "${hash_file} is missing or empty: user.users.<name>.hashedPasswordFile needs it"
fi

log "persistent state ready:"
du -sh "${PERSISTENT_DIR}" 2>/dev/null || true
log "next steps (run as your user):"
cat >&2 <<'EOF'
  ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub   # record the fingerprint
  nrb                                                # build the new system
  nro                                                # make it the next boot
  sudo reboot

After the reboot:
  findmnt /                 # tmpfs
  findmnt /persistent       # btrfs, subvol=/persistent
  sudo -v                   # password and sudo still work
EOF

if [[ ${MOUNTED_BY_US} -eq 1 ]]; then
  log "${PERSISTENT_DIR} is left mounted; the new generation mounts it at boot"
fi
