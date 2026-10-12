#!/usr/bin/env bash

# List all git repos under ~/repos/{personal,work} and open the selected one
# in a new tmux session: window 1 = nvim (left) + lazygit (right), window 2 =
# opencode (left) + shell (right). Windows are explicitly named and protected
# from auto-renaming.
#
# Uses `tv` (television) as the picker via --source-command so selection is
# captured with --source-output "{}". Falls back to plain select if absent.
# Bind in tmux: bind R display-popup -w 70% -h 60% -E "<this script>"

set -euo pipefail
DEBUG_LOG="${REPO_SWITCHER_LOG:-/tmp/repo-switcher.log}"
log() { printf '[%s] %s\n' "$(date +%T)" "$*" >>"$DEBUG_LOG"; }
log "== start =="

repos_root="${REPOS_ROOT:-$HOME/repos}"

targets=()
for base in personal work; do
  dir="$repos_root/$base"
  [ -d "$dir" ] || continue
  for d in "$dir"/*/; do
    [ -d "$d/.git" ] || continue
    targets+=("$d")
  done
done
log "targets=${targets[*]:-none}"

if [ "${#targets[@]}" -eq 0 ]; then
  tmux display-message "No git repos found under $repos_root/{personal,work}"
  exit 0
fi

label() { printf '%s/%s' "$(basename "$(dirname "$1")")" "$(basename "$1")"; }

# Build a tv source-command that echoes "<area>/<name>" for each repo.
args=()
for t in "${targets[@]}"; do
  args+=("$(label "$t")")
done
src_cmd="printf '%s\n' ${args[*]@Q}"

choose() {
  if command -v tv >/dev/null 2>&1; then
    log "picker=tv"
    tv --source-command "$src_cmd" --source-output "{}"
    rc=$?
    log "tv exit=$rc"
    return $rc
  fi
  log "picker=select"
  local i
  for i in "${!targets[@]}"; do
    printf '%2d) %s\n' "$((i + 1))" "$(label "${targets[$i]}")"
  done >&2
  printf 'Select repo: ' >&2
  local sel
  read -r sel
  [[ $sel =~ ^[0-9]+$ ]] && echo "${targets[$((sel - 1))]}" && return 0
  return 1
}

choice=$(choose)
rc=$?
log "choice='$choice' rc=$rc"
[ $rc -eq 0 ] && [ -n "$choice" ] || exit 0

case "$choice" in
personal/*) repo="$repos_root/personal/${choice#personal/}" ;;
work/*) repo="$repos_root/work/${choice#work/}" ;;
*)
  log "bad choice format: $choice"
  exit 0
  ;;
esac
log "repo=$repo"

session="$(basename "$repo")"

if tmux has-session -t "$session" 2>/dev/null; then
  log "session=$session exists; switching"
  tmux switch-client -t "$session" 2>>"$DEBUG_LOG"
  log "switch rc=$?"
  log "== done =="
  exit 0
fi

log "creating session=$session"

# Window 1: editor + lazygit side by side.
tmux new-session -d -s "$session" -n nvim -c "$repo" "${EDITOR:-nvim}" 2>>"$DEBUG_LOG"
log "new-session rc=$?"
{
  tmux set-window-option -t "$session:nvim" automatic-rename off
  tmux set-window-option -t "$session:nvim" allow-rename off
} 2>>"$DEBUG_LOG"
tmux split-window -h -p 40 -t "$session:nvim" -c "$repo" lazygit 2>>"$DEBUG_LOG"
log "split lazygit rc=$?"
tmux select-pane -t "$session:nvim.1" 2>>"$DEBUG_LOG"
log "select editor pane rc=$?"

# Window 2: opencode agent + shell side by side.
tmux new-window -t "$session" -n opencode -c "$repo" opencode 2>>"$DEBUG_LOG"
log "new-window opencode rc=$?"
{
  tmux set-window-option -t "$session:opencode" automatic-rename off
  tmux set-window-option -t "$session:opencode" allow-rename off
} 2>>"$DEBUG_LOG"
tmux split-window -h -p 40 -t "$session:opencode" -c "$repo" 2>>"$DEBUG_LOG"
log "split shell rc=$?"

tmux select-window -t "$session:nvim" 2>>"$DEBUG_LOG"
log "select window rc=$?"
tmux switch-client -t "$session" 2>>"$DEBUG_LOG"
log "switch rc=$?"
log "== done =="
