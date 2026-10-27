# shellcheck shell=bash
# shellcheck disable=SC2154
#
# Appended to samleeney/tmux-agent-status `scripts/lib/collect.sh` at build
# time (the derivation also inserts `opencode_state_bridge` as the first line
# of collect_data()). Its process scan only matches claude/codex/devin, so
# opencode would never register on its own.
#
# opencode runs the nixconf V2 session-status plugin, which writes one JSON per
# process to ~/.local/state/opencode/agent-status/<pid>.json. Each record
# carries the pane's TMUX_PANE. This bridge maps those records onto the
# per-pane status files the collector already reads:
#
#   PANE_DIR/<session>_<%pane>.agent   -> "opencode"
#   PANE_DIR/<session>_<%pane>.status  -> ask | working | done
#
# Writes go through tmp+mv (like the plugin's own hooks) so the PANE_DIR mtime
# only changes on an actual state change, keeping collect_data()'s fast-path
# early return intact between transitions.
declare -A oc_pane_sess oc_panes

# _oc_write <pane_id> <state>: write/refresh the per-pane files, only touching
# them when the content would actually change.
_oc_write() {
  local pid="$1" state="$2" cur
  local sess="${oc_pane_sess[$pid]}"
  local base="$PANE_DIR/${sess}_$pid"

  cur="$(cat "$base.agent" 2>/dev/null || true)"
  if [ "$cur" != "opencode" ]; then
    printf '%s\n' "opencode" >"$base.agent.tmp"
    mv -f -- "$base.agent.tmp" "$base.agent"
  fi
  cur="$(cat "$base.status" 2>/dev/null || true)"
  if [ "$cur" != "$state" ]; then
    printf '%s\n' "$state" >"$base.status.tmp"
    mv -f -- "$base.status.tmp" "$base.status"
  fi
}

opencode_state_bridge() {
  local dir json pid pane state cur sname pane_id oc_tab
  oc_pane_sess=()
  oc_panes=()

  dir="${OPENCODE_STATUS_DIR:-$HOME/.local/state/opencode/agent-status}"
  [ -d "$dir" ] || return 0
  [ -n "${PANE_DIR:-}" ] && [ -d "$PANE_DIR" ] || return 0

  # pane_id -> session, matching collect.sh's list-panes shape. TMUX_PANE is
  # inherited by opencode even on a nested pty (devenv), so the JSON's
  # tmuxPane is the reliable identity. A real tab is interpolated, not \"\\t\"
  # in the format: some tmux builds emit the literal backslash-t otherwise.
  oc_tab=$'\t'
  while IFS=$'\t' read -r sname pane_id; do
    [ -n "$pane_id" ] && oc_pane_sess[$pane_id]="$sname"
  done < <(tmux list-panes -a -F "#{session_name}${oc_tab}#{pane_id}" 2>/dev/null)
  [ "${#oc_pane_sess[@]}" -gt 0 ] || return 0

  for json in "$dir"/*.json; do
    [ -f "$json" ] || continue
    pid="$(jq -r '.pid // 0' "$json" 2>/dev/null)"
    [ "$pid" -gt 0 ] 2>/dev/null || continue
    kill -0 "$pid" 2>/dev/null || continue
    pane="$(jq -r '.tmuxPane // empty' "$json" 2>/dev/null)"
    [ -n "$pane" ] || continue
    [ -n "${oc_pane_sess[$pane]:-}" ] || continue

    case "$(jq -r '.interactionType // empty' "$json" 2>/dev/null)" in
    question)
      state="ask"
      ;;
    *)
      case "$(jq -r '.status // empty' "$json" 2>/dev/null)" in
      busy | retry | working | thinking) state="working" ;;
      *) state="done" ;;
      esac
      ;;
    esac

    # Several opencode processes can share a pane (parallel subagents): keep
    # the highest-priority state, working > ask > done.
    cur="${oc_panes[$pane]:-}"
    if [ -z "$cur" ] ||
      { [ "$state" = "working" ] && [ "$cur" != "working" ]; } ||
      { [ "$state" = "ask" ] && [ "$cur" = "done" ]; }; then
      oc_panes[$pane]="$state"
    fi
  done

  local key
  for key in "${!oc_panes[@]}"; do
    _oc_write "$key" "${oc_panes[$key]}"
  done

  # Retire markers for opencode processes that exited while their pane stayed
  # open, so a finished agent is not stuck showing a stale working state.
  local f bname p
  for f in "$PANE_DIR"/*.agent; do
    [ -f "$f" ] || continue
    [ "$(<"$f")" = "opencode" ] || continue
    bname="${f##*/}"
    bname="${bname%.agent}"
    p="${bname##*_}"
    [ -n "${oc_panes[$p]:-}" ] && continue
    rm -f -- "$PANE_DIR/$bname.status" "$PANE_DIR/$bname.agent"
  done
}
