#!/usr/bin/env bash

# SSH host manager: pick a `user@host` (from ~/.ssh/config, following its
# `Include` globs) and attach a persistent remote tmux session on it (or a
# plain shell). The first picker entry lets you type an arbitrary target.
# tv picker, falling back to plain select. Bind in tmux:
#   bind S display-popup -w 70% -h 60% -E "<this script>"

set -euo pipefail
DEBUG_LOG="${SSH_SWITCHER_LOG:-/tmp/ssh-switcher.log}"
log() { printf '[%s] %s\n' "$(date +%T)" "$*" >>"$DEBUG_LOG"; }
log "== start =="

config="${SSH_CONFIG_FILE:-$HOME/.ssh/config}"
[ -f "$config" ] || {
  log "no ssh config at $config"
  tmux display-message "No SSH config at $config"
  exit 0
}

# Resolve `Host` blocks recursively, following `Include` globs (ssh expands
# them itself; ~ maps to $HOME). Wildcard/pattern aliases are not connectable.
# `users` holds the `User` of the surrounding Host block, parallel to `hosts`.
# Word splitting via `read -ra` (no pathname expansion) so pattern-only lines
# like `Host *` can't glob the current directory.
hosts=()
users=()
seen=()
add_hosts() {
  local file="$1" line pattern sub
  local -a words
  local block_user="" block_start
  [ -f "$file" ] || return 0
  flush_block() {
    local i u="${block_user:-}"
    [ -n "$u" ] || return 0
    for ((i = block_start; i < ${#hosts[@]}; i++)); do
      [ -n "${users[i]:-}" ] || users[i]="$u"
    done
  }
  while IFS= read -r line; do
    read -ra words <<<"$line"
    case "${words[0]:-}" in
    Include)
      for pattern in "${words[@]:1}"; do
        [ -n "$pattern" ] || continue
        pattern="${pattern/#\~/$HOME}"
        # shellcheck disable=SC2086
        for sub in $pattern; do
          [ -f "$sub" ] && add_hosts "$sub"
        done
      done
      ;;
    Host)
      flush_block
      block_start=${#hosts[@]}
      block_user=""
      for pattern in "${words[@]:1}"; do
        [ -n "$pattern" ] || continue
        [[ $pattern == *[?*]* ]] && continue
        if ! printf '%s\n' "${seen[@]}" | grep -qxF "$pattern"; then
          seen+=("$pattern")
          hosts+=("$pattern")
          users+=("")
        fi
      done
      ;;
    User)
      [ $# -ge 1 ] && block_user="${words[1]:-}"
      ;;
    esac
  done <"$file"
  flush_block
}
add_hosts "$config"
log "hosts=${hosts[*]:-none}"

entries=()
for i in "${!hosts[@]}"; do
  if [ -n "${users[$i]:-}" ]; then
    entries+=("${users[$i]}@${hosts[$i]}")
  else
    entries+=("${hosts[$i]}")
  fi
done
log "entries=${entries[*]:-none}"

# Always offer a typed target so any host works, even never written to a
# config file (server.alexyz.org, ad-hoc boxes, fresh VMs, ...).
choices=("Type a user@host…" "${entries[@]}")

pick() {
  local -a items=("$@")
  if command -v tv >/dev/null 2>&1; then
    log "picker=tv"
    tv --source-command "printf '%s\n' ${items[*]@Q}" --source-output "{}"
    rc=$?
    log "tv exit=$rc"
    return $rc
  fi
  log "picker=select"
  local i
  for i in "${!items[@]}"; do
    printf '%2d) %s\n' "$((i + 1))" "${items[$i]}"
  done >&2
  printf 'Select: ' >&2
  local sel
  read -r sel
  [[ $sel =~ ^[0-9]+$ ]] && echo "${items[$((sel - 1))]}" && return 0
  return 1
}

target="$(pick "${choices[@]}")"
rc=$?
log "target='$target' rc=$rc"
[ $rc -eq 0 ] && [ -n "$target" ] || exit 0

if [ "$target" = "Type a user@host…" ]; then
  printf 'target (user@host): ' >&2
  read -r target
  [ -n "$target" ] || exit 0
  log "typed target=$target"
fi

# Split the picked target into user and host; `user@host` or plain `host`.
if [[ $target == *@* ]]; then
  ssh_host="${target##*@}"
else
  ssh_host="$target"
fi
[ -n "$ssh_host" ] || exit 0
log "ssh_host=$ssh_host"

actions=("Attach tmux (persistent)" "Plain shell")
action="$(pick "${actions[@]}")"
rc=$?
log "action='$action' rc=$rc"
[ $rc -eq 0 ] && [ -n "$action" ] || exit 0

case "$action" in
"Attach tmux (persistent)")
  # The remote command is single-quoted so the local shell hands `$SHELL` to
  # the host untouched; tmux on the remote gets used if present, otherwise we
  # land in a plain remote shell (no scary "tmux: command not found").
  run_cmd="ssh -tt ${target@Q} 'command -v tmux >/dev/null 2>&1 && tmux new -A -s main || exec \$SHELL'"
  ;;
"Plain shell")
  run_cmd="ssh -tt ${target@Q}"
  ;;
*)
  log "bad action: $action"
  exit 0
  ;;
esac
log "run_cmd=$run_cmd"

session="ssh-$(printf '%s' "$ssh_host" | tr -c 'A-Za-z0-9_-' '_')"
log "session=$session"

if tmux has-session -t "$session" 2>/dev/null; then
  log "session=$session exists; switching"
  tmux switch-client -t "$session" 2>>"$DEBUG_LOG"
  log "switch rc=$?"
  log "== done =="
  exit 0
fi

log "creating session=$session"
tmux new-session -d -s "$session" -n "$ssh_host" -c "$HOME" "$run_cmd" 2>>"$DEBUG_LOG"
log "new-session rc=$?"
{
  tmux set-window-option -t "$session:$ssh_host" automatic-rename off
  tmux set-window-option -t "$session:$ssh_host" allow-rename off
} 2>>"$DEBUG_LOG"
tmux switch-client -t "$session" 2>>"$DEBUG_LOG"
log "switch rc=$?"
log "== done =="
