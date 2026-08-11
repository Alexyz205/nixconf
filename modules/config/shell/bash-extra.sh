# ===============================================
# Bash Options
# ===============================================
shopt -s histappend
shopt -s checkwinsize
shopt -s extglob
shopt -s nocaseglob
shopt -s cdspell

# ===============================================
# History Configuration
# ===============================================
# Update history after each command
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# ===============================================
# Key Bindings
# ===============================================
# Completion using arrow keys (based on history)
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# ===============================================
# Vi Mode
# ===============================================
set -o vi

# ===============================================
# Television (Fuzzy Finder) shell integration
# ===============================================
eval "$(tv init bash)" 2>/dev/null || true

# Override Ctrl+T to launch tv files channel on empty prompt
tv_smart_autocomplete() {
  _disable_bracketed_paste
  local tokens prefix lbuf
  local current_prompt="${READLINE_LINE:0:$READLINE_POINT}"
  read -ra tokens <<< "$current_prompt"
  if [[ ${#tokens[@]} -lt 1 ]]; then
    local output
    printf "\n"
    output=$(tv files --no-status-bar --inline)
    if [[ -n "$output" ]]; then
      READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${output}"
      READLINE_POINT=$(( READLINE_POINT + ${#output} ))
    fi
    printf "\033[A"
    _enable_bracketed_paste
    return
  fi
  [[ "${READLINE_LINE:$((READLINE_POINT-1)):1}" == " " ]] && tokens+=("")
  prefix="${tokens[-1]}"
  if [[ -n "$prefix" ]]; then
    lbuf="${current_prompt:0:$((${#current_prompt} - ${#prefix}))}"
  else
    lbuf="$current_prompt"
  fi
  __tv_path_completion "$prefix" "$lbuf"
  _enable_bracketed_paste
}

# Override Ctrl+R history to use cable channel with dedup
tv_shell_history() {
  _disable_bracketed_paste
  local current_prompt="${READLINE_LINE:0:$READLINE_POINT}"
  local output
  printf "\n"
  output=$(tv bash-history --no-status-bar --input "$current_prompt" --inline)
  if [[ -n "$output" ]]; then
    READLINE_LINE="$output"
    READLINE_POINT=${#READLINE_LINE}
  fi
  printf "\033[A"
  _enable_bracketed_paste
}

# ===============================================
# Tmux Auto-Start
# ===============================================
tmux_auto_start
