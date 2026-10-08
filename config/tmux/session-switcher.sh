#!/usr/bin/env bash
# tmux session/window manager with tv (television) as the picker, mirroring
# the tmux-fzf flow: pick a window, then pick an action (switch / rename /
# kill). Falls back to `tmux choose-session` when tv is unavailable.
# Bind in tmux: bind F display-popup -w 70% -h 60% -E "<wrapped script>"

set -euo pipefail
DEBUG_LOG="${SESSION_SWITCHER_LOG:-/tmp/session-switcher.log}"
log() { printf '[%s] %s\n' "$(date +%T)" "$*" >>"$DEBUG_LOG"; }
log "== start =="

targets=$(tmux list-windows -a -F '#{session_name}:#{window_index}'$'\t''#{window_name}' 2>/dev/null) || true
log "targets='$(printf '%s' "$targets" | tr '\t' ' ' | sed -n '1p')'"
[ -n "$targets" ] || {
  tmux display-message "no tmux sessions"
  exit 0
}
src_cmd="printf '%s\n' ${targets@Q}"

tv_pick() {
  command -v tv >/dev/null 2>&1 || return 1
  tv --source-command "$1" --source-output "{}"
}

choice=$(tv_pick "$src_cmd") || {
  exec tmux choose-session
}
[ -n "$choice" ] || exit 0

target="${choice%%$'\t'*}"
session="${target%%:*}"
log "target=$target session=$session"
[ -n "$target" ] || exit 0

action_list=(
  "Switch: $target"
  "Rename window: $target"
  "Kill window: $target"
  "Rename session: $session"
  "Kill session: $session"
)
action_src="printf '%s\n' ${action_list[*]@Q}"
action=$(tv_pick "$action_src") || exit 0
log "action=$action"
[ -n "$action" ] || exit 0

case "$action" in
"Switch: "*)
  tmux switch-client -t "$session"
  tmux select-window -t "$target"
  ;;
"Rename window: "*)
  read -rp "New window name for $target: " name || exit 0
  [ -n "$name" ] && tmux rename-window -t "$target" "$name"
  ;;
"Kill window: "*)
  read -rp "Kill window $target? (y/N) " ans || exit 0
  [[ ${ans,,} == y ]] && tmux kill-window -t "$target"
  ;;
"Rename session: "*)
  read -rp "New session name for $session: " name || exit 0
  [ -n "$name" ] && tmux rename-session -t "$session" "$name"
  ;;
"Kill session: "*)
  read -rp "Kill session $session? (y/N) " ans || exit 0
  [[ ${ans,,} == y ]] && tmux kill-session -t "$session"
  ;;
esac
log "== done =="
