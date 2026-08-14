#!/usr/bin/env bash
# tmux control panel for the nixconf repo.
# Invoked from within a display-popup; runs the action directly.
set -euo pipefail

LOG="${NIXCONF_MENU_LOG:-/tmp/nixconf-menu.log}"
log() { printf '[%s] %s\n' "$(date '+%T')" "$*" >>"$LOG"; }
log "== invoke args='${1:-}' cwd='$(pwd)' =="

NIXCONF="${NIXCONF:-$HOME/repos/personal/nixconf}"
REPO_SWITCHER="$NIXCONF/modules/config/tmux/repo-switcher.sh"

[ -d "$NIXCONF/modules" ] || { log "NIXCONF missing: $NIXCONF"; tmux display-message "nixconf not found: $NIXCONF"; exit 0; }

case "${1:-}" in
  sessions)    log "sessions"; exec tmux choose-session ;;
  new-session) log "new-session"; exec bash -c "read -p 'Session name: ' n && tmux new-session -d -s \"\$n\" -c \"\$PWD\" && tmux switch-client -t \"\$n\"" ;;
  repo-switch) log "repo-switch"; exec "$REPO_SWITCHER" ;;
  lazygit)     log "lazygit"; exec lazygit ;;
  yazi)        log "yazi"; exec yazi ;;
  *)           log "unknown arg: ${1:-none}"; tmux display-message "unknown menu action: ${1:-none}"; exit 0 ;;
esac