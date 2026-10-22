#!/usr/bin/env bash
# Smart tmux window names, called from hooks with the target window id.
#
# Priority:
#   1. opencode session title (pane title "OC | <session title>")
#   2. SSH pane title
#   3. git repository name of the active pane's directory
#   4. basename of the active pane's directory/title
#   5. active pane command
#
# The computed name is stored in the `@smart-name` window option, which the
# global `automatic-rename-format` prefers. That way re-enabling
# `automatic-rename` (needed to keep tmux's own auto-rename in sync) re-applies
# our name instead of the pane title. A manual rename turns `automatic-rename`
# off, which pauses this script so the manual name sticks.

set -euo pipefail

win="${1:-}"
[ -n "$win" ] || exit 0

auto="$(tmux display-message -p -t "$win" '#{automatic-rename}' 2>/dev/null || true)"
[ "$auto" = "1" ] || exit 0

tab=$'\t'
oc_active="" oc_first=""
active_cmd="" active_path="" active_title=""

while IFS=$tab read -r pane_active pane_cmd pane_path pane_title; do
  [ "$pane_title" = "agent-sidebar" ] && continue

  case "$pane_title" in
  "OC | "*)
    title="${pane_title#OC | }"
    [ -n "$oc_first" ] || oc_first="$title"
    [ "$pane_active" = "1" ] && oc_active="$title"
    ;;
  esac

  if [ "$pane_active" = "1" ]; then
    active_cmd="$pane_cmd"
    active_path="$pane_path"
    active_title="$pane_title"
  fi
done < <(tmux list-panes -t "$win" -F "#{pane_active}${tab}#{pane_current_command}${tab}#{pane_current_path}${tab}#{pane_title}" 2>/dev/null)

name=""
has_opencode=0
if [ -n "$oc_active" ] || [ -n "$oc_first" ]; then
  name="${oc_active:-$oc_first}"
  has_opencode=1
elif [ "$active_cmd" = "ssh" ] || [ "$active_cmd" = "sshpass" ]; then
  name="$active_title"
elif [ -n "$active_path" ]; then
  repo="$(git -C "$active_path" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$repo" ]; then
    name="${repo##*/}"
  else
    name="${active_path%/}"
    name="${name##*/}"
  fi
fi

if [ -z "$name" ]; then
  case "$active_title" in
  "" | "agent-sidebar") ;;
  */*)
    name="${active_title%/}"
    name="${name##*/}"
    ;;
  *) name="$active_title" ;;
  esac
fi

[ -n "$name" ] || name="${active_cmd##*/}"
[ -n "$name" ] || exit 0

name="${name//[$'\n\t']/ }"
name="${name#"${name%%[![:space:]]*}"}"
name="${name%"${name##*[![:space:]]}"}"
[ -n "$name" ] || exit 0

if [ "${#name}" -gt 30 ]; then
  name="${name:0:29}…"
fi

if [ "$has_opencode" = "1" ]; then
  name="OC | $name"
fi

tmux set-window-option -t "$win" @smart-name "$name"

current="$(tmux display-message -p -t "$win" '#{window_name}' 2>/dev/null || true)"
[ "$name" = "$current" ] && exit 0

tmux rename-window -t "$win" -- "$name" 2>/dev/null || tmux rename-window -t "$win" "$name"
tmux set-window-option -t "$win" automatic-rename on
