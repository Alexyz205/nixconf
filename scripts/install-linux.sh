#!/usr/bin/env bash
# =========================================================
# install-linux.sh — standalone Nix + dev tools for any Linux box
#
# Installs Nix (official installer, no curl|sh pipe), clones the
# nixconf repo, and installs the bundled tool stack via `nix profile`
# (`.#tools`). No home-manager, no host config — just your dev tools.
#
# Usage:  ./scripts/install-linux.sh [options]
# =========================================================
set -euo pipefail

NIX_CONF="${NIXCONF:-$HOME/repos/personal/nixconf}"
REPO_URL="${NIXCONF_REPO_URL:-https://github.com/Alexyz205/nixconf.git}"
INSTALL_DIR="${NIX_CONF}"
INSTALL_NIX=1
ASSUME_YES=0

usage() {
  cat <<EOF
Usage: install-linux.sh [options]

Bootstraps a standalone Nix + dev-tools environment on Linux:

  1. Installs Nix (official installer) if missing — enables flakes.
  2. Clones this repo to \$HOME/repos/personal/nixconf.
  3. Installs the tool stack via 'nix profile install .#tools'.

No home-manager, no system config — just the dev tools.

Options:
  -y, --yes            Assume yes to all prompts
  -n, --no-nix         Skip the Nix installer (Nix already present)
  -d, --dir DIR        Clone target directory (default: \$HOME/repos/personal/nixconf)
  -u, --url URL        Repo URL to clone (default: github.com/Alexyz205/nixconf)
  -h, --help           Show this help message

Exit codes: 0=success 1=error 2=usage 3=dependencies
EOF
}

log() { printf '==> %s\n' "$*" >&2; }
warn() { printf '!!  %s\n' "$*" >&2; }
err() { printf '[ERROR] %s\n' "$*" >&2; }

confirm() {
  local prompt="$1"
  if [ "$ASSUME_YES" = "1" ]; then
    return 0
  fi
  local reply
  printf '%s [y/N] ' "$prompt" >&2
  read -r reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)    ASSUME_YES=1 ;;
    -n|--no-nix) INSTALL_NIX=0 ;;
    -d|--dir)    INSTALL_DIR="$2"; shift ;;
    -u|--url)    REPO_URL="$2"; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          err "Unknown option: $1"; usage >&2; exit 2 ;;
    *)           err "Unexpected argument: $1"; usage >&2; exit 2 ;;
  esac
  shift
done

check_deps() {
  local missing=()
  for cmd in curl git; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    err "Missing dependencies: ${missing[*]}"
    err "Install them with your package manager, e.g. apt install git curl"
    exit 3
  fi
}

ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    log "Nix already installed ($(nix --version))"
    return 0
  fi
  if [ "$INSTALL_NIX" = "0" ]; then
    err "Nix is required but not found; pass without --no-nix to install it."
    exit 3
  fi

  if ! confirm "Nix is not installed. Download and run the official installer?"; then
    err "Aborted — install Nix manually: https://nixos.org/download/"
    exit 1
  fi

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/nix-install.XXXXXX.sh")"
  trap 'rm -f "$tmp"' EXIT

  log "Downloading official Nix installer..."
  if ! curl -fsSL https://nixos.org/nix/install -o "$tmp"; then
    err "Failed to download the Nix installer."
    exit 1
  fi

  log "Running installer (multi-user, daemon mode)..."
  # Run as the current user; sudo prompts appear if needed. NOT piped.
  if ! sh "$tmp" --daemon; then
    err "Nix installer failed."
    exit 1
  fi

  # The installer prints this path; add it to the current shell session too.
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
  log "Nix installed. Note: you may need to start a new shell for PATH updates."
}

ensure_flakes() {
  local nix_conf="$HOME/.config/nix/nix.conf"
  if ! grep -q '^experimental-features' "$nix_conf" 2>/dev/null; then
    log "Enabling flakes + nix-command in $nix_conf"
    mkdir -p "$(dirname "$nix_conf")"
    printf '\nexperimental-features = nix-command flakes\n' >>"$nix_conf"
  fi
}

clone_repo() {
  if [ -d "$INSTALL_DIR/.git" ]; then
    log "Repo already cloned at $INSTALL_DIR"
    return 0
  fi
  log "Cloning $REPO_URL -> $INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR"
}

install_tools() {
  local tools_ref="$INSTALL_DIR#tools"
  log "Installing dev tools via 'nix profile install $tools_ref'..."
  if ! confirm "Install the nixconf tool stack into your user profile?"; then
    warn "Skipped tools install. Re-run with 'nix profile install $tools_ref'."
    return 0
  fi
  # shellcheck disable=SC2016
  (cd "$INSTALL_DIR" && nix --extra-experimental-features "nix-command flakes" profile install '.#tools')
  log "Tools installed. Run 'nix profile list' to verify."
}

main() {
  check_deps
  ensure_nix
  ensure_flakes
  clone_repo
  install_tools

  cat <<EOF

Installation complete.

What was set up:
  - Nix:          $(nix --version 2>/dev/null || echo "not found in this shell")
  - Flakes:       enabled in $HOME/.config/nix/nix.conf
  - Repo:         $INSTALL_DIR
  - Tools:        nix profile (see: nix profile list)

Next steps:
  1. Restart your shell (or 'source ~/.bashrc') so Nix's PATH is active.
  2. The tool stack is now on your PATH: git, neovim, lazygit, gh, ripgrep,
     fd, bat, eza, zoxide, starship, tmux, yazi, btop, jq, yq, delta, sops ...
  3. For the full home-manager config (aliases, LazyVim, dotfiles), the
     standalone profiles live in the repo:
         nix run "$INSTALL_DIR#homeConfigurations.alexis@linux.activationPackage"
     (NixOS hosts use 'nr'/'hm' aliases instead.)

To remove the tools later:
  nix profile remove 0   # or the index shown by 'nix profile list'
EOF
}

main "$@"