# shellcheck shell=bash
#
# Appended to tmux-agent-status' lib/classify.sh at build time.
#
# classify_pane is re-defined to keep the upstream tty scan but ADD an
# environment fallback: in devenv agents often run on a NESTED pty that
# inherits TMUX_PANE but has a different tty than the pane, so `ps -t` misses
# them. Candidate agent pids are found cheaply via /proc comm, then attributed
# to a pane when their TMUX_PANE env matches.
#
# classify_state is re-defined so opencode gets real working/blocked/idle
# labels from the opencode-session-status event plugin (per-process JSON keyed
# by the pane's TMUX_PANE); falls back to presence-only ("unknown").
classify_pane() {
  local pane_id="$3" pane_tty="$6"
  local short="${pane_tty#/dev/}"
  local procs agents fg_set=" " any_set=" " state rest cmd base pid env_tp
  local c cand=""
  [ -n "$short" ] || {
    echo none
    return
  }
  procs="$(ps -t "$short" -o state=,command= 2>/dev/null)"
  [ -n "$procs" ] || {
    echo none
    return
  }
  agents="$(agent_status_agents)"

  while read -r state rest; do
    [ -n "$rest" ] || continue
    cmd="${rest%% *}"
    base="${cmd##*/}"
    for agent in $agents; do
      [ "$base" = "$agent" ] || continue
      case "$state" in
      *+*)
        case "$fg_set" in *" $agent "*) ;; *) fg_set="$fg_set$agent " ;; esac
        ;;
      *)
        case "$any_set" in *" $agent "*) ;; *) any_set="$any_set$agent " ;; esac
        ;;
      esac
    done
  done <<EOF
$procs
EOF

  for agent in $agents; do
    case "$fg_set" in *" $agent "*) echo "$agent" && return ;; esac
  done
  for agent in $agents; do
    case "$any_set" in *" $agent "*) echo "$agent" && return ;; esac
  done

  # TMUX_PANE env fallback (nested-pty / devenv panes).
  for d in /proc/[0-9]*; do
    read -r c <"$d/comm" 2>/dev/null || continue
    for agent in $agents; do
      [ "$c" = "$agent" ] && cand="$cand ${d#/proc/}:$agent"
    done
  done
  for entry in $cand; do
    pid="${entry%%:*}"
    agent="${entry##*:}"
    env_tp="$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | grep "^TMUX_PANE=$pane_id$" | head -1)"
    [ -n "$env_tp" ] || continue
    echo "$agent"
    return
  done
  echo none
}

# Re-defines classify_state so opencode drives the same working/blocked/idle
# labels from the opencode-session-status event plugin.
opencode_state() {
  local pane_id="$1" dir f pid pane matched=0 working=0
  dir="${OPENCODE_STATUS_DIR:-$HOME/.local/state/opencode/agent-status}"
  [ -d "$dir" ] || {
    echo unknown
    return
  }
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    pid="$(jq -r '.pid // 0' "$f" 2>/dev/null)"
    [ "$pid" -gt 0 ] 2>/dev/null || continue
    kill -0 "$pid" 2>/dev/null || continue
    pane="$(jq -r '.tmuxPane // empty' "$f" 2>/dev/null)"
    [ "$pane" = "$pane_id" ] || continue
    matched=1
    case "$(jq -r '.state // empty' "$f" 2>/dev/null)" in
    question)
      echo blocked
      return
      ;;
    busy) working=1 ;;
    esac
  done
  if [ "$matched" = 1 ]; then
    [ "$working" = 1 ] && echo working || echo idle
    return
  fi
  echo unknown
}

classify_state() {
  local pane_id="$1" agent="$2" buf
  case "$agent" in
  opencode | .opencode-wrapp)
    opencode_state "$pane_id"
    ;;
  claude)
    buf="$(tmux capture-pane -p -t "$pane_id" 2>/dev/null)"
    [ -n "$buf" ] || {
      echo unknown
      return
    }
    if printf '%s\n' "$buf" | grep -qE 'esc to interrupt|…[[:space:]]*\([0-9]'; then
      echo working
      return
    fi
    if printf '%s\n' "$buf" | grep -qE '❯[[:space:]]+[0-9]+\.'; then
      echo blocked
      return
    fi
    echo waiting
    return
    ;;
  *)
    echo unknown
    return
    ;;
  esac
}
