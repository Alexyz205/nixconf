#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
cd "$SCRIPT_DIR"

NIXOS_HOSTS=(workstation headless-worker proxmox-vm installer-iso)
HOME_CONFIGS=("alexis@linux" "alexis.pigeon@RNSL-APIGEON5" "alexis@server" "root@container")
DISKO_HOSTS=(workstation headless-worker)
ALL_TESTS=(flake eval disko iso vm shellcheck)

log() { printf '==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }
fail() { printf '    FAIL: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [TEST ...]

Runs repository tests. Without arguments, runs all tests.

Available tests:
$(printf '  %s\n' "${ALL_TESTS[@]}")

Options:
  all           Run every test
  -h, --help    Show this help message
  -l, --list    List available tests and exit
EOF
}

test_flake() {
  log "nix flake check"
  nix flake check
}

test_eval() {
  log "evaluating NixOS configurations"
  local h
  for h in "${NIXOS_HOSTS[@]}"; do
    log "  .#nixosConfigurations.$h"
    nix build --dry-run ".#nixosConfigurations.$h.config.system.build.toplevel" >/dev/null
  done

  log "evaluating home-manager configurations"
  local hc
  for hc in "${HOME_CONFIGS[@]}"; do
    log "  .#homeConfigurations.\"$hc\""
    nix build --dry-run ".#homeConfigurations.\"$hc\".activationPackage" >/dev/null
  done
}

test_disko() {
  log "disko dry-run"
  local h
  for h in "${DISKO_HOSTS[@]}"; do
    log "  disko --dry-run --flake .#$h"
    disko --dry-run --mode destroy,format,mount --flake "$SCRIPT_DIR#$h" >/dev/null
  done
}

test_iso() {
  log "building ISO image"
  nix build ".#nixosConfigurations.installer-iso.config.system.build.isoImage" --no-link --print-out-paths
}

test_vm() {
  log "building proxmox-vm image"
  nix build ".#proxmox-vm" --no-link --print-out-paths
}

test_shellcheck() {
  log "shellcheck"
  local s
  for s in "$SCRIPT_DIR"/scripts/*.sh; do
    log "  $s"
    shellcheck -S warning "$s"
  done
}

run_test() {
  local name="$1"
  log "----------------------------------------"
  if "test_$name"; then
    ok "$name"
  else
    fail "$name"
    return 1
  fi
}

main() {
  local tests=()
  local arg

  if [[ $# -eq 0 ]]; then
    tests=("${ALL_TESTS[@]}")
  else
    for arg in "$@"; do
      case "$arg" in
      -h | --help)
        usage
        exit 0
        ;;
      -l | --list)
        printf '%s\n' "${ALL_TESTS[@]}"
        exit 0
        ;;
      all) tests=("${ALL_TESTS[@]}") ;;
      *)
        if [[ " ${ALL_TESTS[*]} " == *" $arg "* ]]; then
          tests+=("$arg")
        else
          echo "Unknown test: $arg" >&2
          usage >&2
          exit 2
        fi
        ;;
      esac
    done
  fi

  if ! command -v disko >/dev/null 2>&1 || ! command -v shellcheck >/dev/null 2>&1; then
    log "Missing test tools, re-entering via devenv shell..."
    exec devenv shell -- bash "$SELF" "$@"
  fi

  local failed=()
  local name
  for name in "${tests[@]}"; do
    run_test "$name" || failed+=("$name")
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log "FAILED: ${failed[*]}"
    exit 1
  fi
  log "All tests passed."
}

main "$@"
