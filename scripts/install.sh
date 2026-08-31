#!/usr/bin/env bash
# =========================================================
# install.sh — one installer for every nixconf target
#
# Commands:
#   container (default)  Bootstrap inside a container / devpod: install Nix
#                        (single-user, no systemd), clone the repo, activate
#                        the container home-manager profile. `devpod up`
#                        runs this so the container gets the full dotfiles
#                        (zsh + starship + tmux + tools + aliases).
#   server               Bootstrap a new server / image: install Nix
#                        (multi-user daemon), clone the repo, activate the
#                        server home-manager profile.
#
# Usage:  ./scripts/install.sh [command] [options]
# =========================================================
set -euo pipefail

NIX_CONF="${NIXCONF:-$HOME/repos/personal/nixconf}"
REPO_URL="${NIXCONF_REPO_URL:-https://github.com/Alexyz205/nixconf.git}"
INSTALL_DIR="${NIX_CONF}"

INSTALL_NIX=1
ASSUME_YES=0
COMMAND="container"
HM_CONFIG=""

usage() {
  cat <<EOF
Usage: install.sh [command] [options]

Commands:
  container (default)  Bootstrap inside a container / devpod: single-user Nix,
                       clone repo, activate the container home-manager profile
                       (full dotfiles: zsh, starship, tmux, tools, aliases).
  server               Bootstrap a new server/image: multi-user Nix (daemon),
                       clone repo, activate the server home-manager profile.
  -h, --help           Show this help message

Options:
  -c, --config NAME    Home-manager config to activate.
                       container -> root@container, server -> alexis@server.
                       You can pick any, e.g. '-c alexis@linux'.
  -y, --yes            Assume yes to all prompts
  -n, --no-nix         Skip the Nix installer (Nix already present)
  -d, --dir DIR        Clone target dir (default: \$HOME/repos/personal/nixconf)
  -u, --url URL        Repo URL to clone (default: github.com/Alexyz205/nixconf)

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
  # Non-interactive stdin (devpod / CI bootstrap): assume yes instead of
  # letting `read` fail on EOF and skipping the setup.
  if [ ! -t 0 ]; then
    return 0
  fi
  local reply
  printf '%s [y/N] ' "$prompt" >&2
  read -r reply
  case "$reply" in
  y | Y | yes | YES) return 0 ;;
  *) return 1 ;;
  esac
}

check_deps() {
  local missing=()
  for cmd in curl git; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    return 0
  fi

  if [ "$COMMAND" = "container" ] && command -v apt-get >/dev/null 2>&1; then
    log "Installing missing base deps with apt: ${missing[*]}"
    apt-get update -qq
    apt-get install -y -qq "${missing[@]}" >/dev/null 2>&1 || {
      err "apt failed to install: ${missing[*]}"
      exit 3
    }
    return 0
  fi

  err "Missing dependencies: ${missing[*]}"
  err "Install them with your package manager, e.g. apt install git curl"
  exit 3
}

# -----------------------------------------------------------
# Nix bootstrap (shared by container + server)
# -----------------------------------------------------------

ensure_nix() {
  local mode="$1" # "single" (container) or "daemon" (server)
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
  trap 'rm -f "${tmp:-}"' EXIT

  log "Downloading official Nix installer..."
  if ! curl -fsSL https://nixos.org/nix/install -o "$tmp"; then
    err "Failed to download the Nix installer."
    exit 1
  fi

  if [ "$mode" = "single" ]; then
    # Running as root in a container: the installer wants `sudo` (absent) to
    # create /nix, and Nix hardcodes `build-users-group = nixbld` when run as
    # root (no such group in the image). Pre-create /nix and pin an empty
    # build-users-group so neither is needed — no extra packages required.
    if [ "$(id -u)" = "0" ]; then
      if [ ! -d /nix ]; then
        log "Pre-creating /nix (running as root, no sudo available)..."
        mkdir -m 0755 /nix
        chown root /nix
      fi
      if [ ! -e /etc/nix/nix.conf ]; then
        log "Disabling build-users-group in /etc/nix/nix.conf (no nixbld group)..."
        mkdir -p /etc/nix
        printf 'build-users-group =\n' >/etc/nix/nix.conf
      fi
    fi
    log "Running installer (single-user, no daemon — container mode)..."
    if ! sh "$tmp" --no-daemon; then
      err "Nix installer failed."
      exit 1
    fi
    # shellcheck disable=SC1091
    [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    # nix.sh no-ops unless USER is exported (not set in containers) — put the
    # profile bin on PATH explicitly so nix is usable in this same shell.
    export PATH="$HOME/.nix-profile/bin:$PATH"
    log "Nix installed (single-user). PATH is active in this shell."
  else
    log "Running installer (multi-user, daemon mode)..."
    # Run as the current user; sudo prompts appear if needed. NOT piped.
    if ! sh "$tmp" --daemon; then
      err "Nix installer failed."
      exit 1
    fi
    if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
      # shellcheck disable=SC1091
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    log "Nix installed. Note: you may need to start a new shell for PATH updates."
  fi
}

ensure_flakes() {
  # Every home-manager profile ships the `nix` module, which manages
  # ~/.config/nix/nix.conf (experimental-features, substituters, ssl-cert-file,
  # ...). Pre-writing it here would make activation refuse to clobber it, so
  # leave it to home-manager; `nix run` below passes --extra-experimental-
  # features explicitly for this session.
  :
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

activate_home() {
  local cfg="$HM_CONFIG"
  log "Activating standalone home-manager config '$cfg' (tools + dotfiles + aliases)..."
  if ! confirm "Activate home-manager config '$cfg' now?"; then
    warn "Skipped. Re-run with: nix run '$INSTALL_DIR#homeConfigurations.$cfg.activationPackage'"
    return 0
  fi
  # Containers often lack a USER/LOGNAME export (home-manager activation needs
  # them) and sit behind a TLS-intercepting proxy whose CA is in the system
  # bundle — point nix's git fetches at it so corporate CAs are honoured.
  export USER="${USER:-$(id -un)}"
  export LOGNAME="${LOGNAME:-$USER}"
  if [ -e /etc/ssl/certs/ca-certificates.crt ]; then
    export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    export NIX_GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
  fi
  # shellcheck disable=SC2016
  (cd "$INSTALL_DIR" && nix --extra-experimental-features "nix-command flakes" run "$INSTALL_DIR#homeConfigurations.$cfg.activationPackage")
  log "Home-manager activated. Start a new shell to pick up zsh + aliases."
}

# -----------------------------------------------------------
# container mode (default) / server mode
# -----------------------------------------------------------

cmd_container() {
  check_deps
  HM_CONFIG="${HM_CONFIG:-root@container}"
  ensure_nix single
  ensure_flakes
  clone_repo
  activate_home

  cat <<EOF

Container bootstrap complete.

What was set up:
  - Nix:          single-user (no daemon — containers have no systemd)
  - Flakes:       enabled in $HOME/.config/nix/nix.conf
  - Repo:         $INSTALL_DIR
  - Home-manager: $HM_CONFIG (zsh + starship + tmux + tools + aliases)

Next steps:
  1. Restart your shell (or 'source ~/.zshrc') so the tools + aliases are active.
  2. Project-specific tooling (LSPs, languages) comes from the repo's devenv.nix,
     not from home-manager.
EOF
}

cmd_server() {
  check_deps
  HM_CONFIG="${HM_CONFIG:-alexis@server}"
  ensure_nix daemon
  ensure_flakes
  clone_repo
  activate_home

  cat <<EOF

Server bootstrap complete.

What was set up:
  - Nix:          multi-user (daemon mode)
  - Flakes:       enabled in $HOME/.config/nix/nix.conf
  - Repo:         $INSTALL_DIR
  - Home-manager: $HM_CONFIG (tools: git, neovim/lazyvim, lazygit, gh, bat, eza,
                   zoxide, starship, tmux, yazi, btop, tv, devenv, opencode, ...)

Next steps:
  1. Restart your shell (or 'source ~/.zshrc') so the tools + aliases are active.
  2. Manage it later with 'home-manager switch --flake $INSTALL_DIR'.
EOF
}

# -----------------------------------------------------------
# arg parsing
# -----------------------------------------------------------

main() {
  # First positional arg selects the command; the rest are flags / dirs.
  if [[ $# -gt 0 ]] && [[ $1 == "container" || $1 == "server" ]]; then
    COMMAND="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -y | --yes) ASSUME_YES=1 ;;
    -n | --no-nix) INSTALL_NIX=0 ;;
    -d | --dir)
      INSTALL_DIR="$2"
      shift
      ;;
    -u | --url)
      REPO_URL="$2"
      shift
      ;;
    -c | --config)
      HM_CONFIG="$2"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      err "Unknown option: $1"
      usage >&2
      exit 2
      ;;
    esac
    shift
  done

  case "$COMMAND" in
  container) cmd_container ;;
  server) cmd_server ;;
  esac
}

main "$@"
