# ===============================================
# Shared Shell Functions
# ===============================================

# Clipboard (OSC 52 via tmux, X11 fallback)
function pbcopy() {
  if [ -n "${TMUX:-}" ]; then
    tmux load-buffer -
  elif command -v xclip &>/dev/null; then
    command xclip -selection clipboard
  elif command -v xsel &>/dev/null; then
    command xsel --clipboard --input
  else
    cat >/dev/null
  fi
}

# Tmux Auto-Start
function tmux_auto_start() {
  # Skip if inside a devcontainer or Codespaces
  if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${CODESPACES:-}" ]; then
    return 0
  fi
  # Skip if TMUX_AUTO_START is disabled
  if [ "${TMUX_AUTO_START:-1}" = "0" ]; then
    return 0
  fi
  # Skip if tmux is not available
  if ! command -v tmux &>/dev/null; then
    echo "tmux not found, skipping tmux initialization."
    return 1
  fi
  # Skip if already inside tmux
  if [ -n "$TMUX" ]; then
    clear
    return 0
  fi
  # Attach to existing session or create new one (atomic)
  echo "Starting tmux..."
  tmux new-session -A -s dev
}

# ===============================================
# AI (fabric) pattern aliases + YouTube helper
# ===============================================
if command -v fabric &>/dev/null && [ -d "$HOME/.config/fabric/patterns" ]; then
  for pattern_file in "$HOME"/.config/fabric/patterns/*; do
    [ -e "$pattern_file" ] || continue
    pattern_name="$(basename "$pattern_file")"
    alias_name="${FABRIC_ALIAS_PREFIX:-}${pattern_name}"
    eval "alias $alias_name='fabric --pattern $pattern_name'"
  done

  yt() {
    if [ "$#" -eq 0 ] || [ "$#" -gt 2 ]; then
      echo "Usage: yt [-t | --timestamps] youtube-link"
      echo "Use the '-t' flag to get the transcript with timestamps."
      return 1
    fi

    transcript_flag="--transcript"
    if [ "$1" = "-t" ] || [ "$1" = "--timestamps" ]; then
      transcript_flag="--transcript-with-timestamps"
      shift
    fi
    local video_link="$1"
    fabric -y "$video_link" $transcript_flag
  }
fi
