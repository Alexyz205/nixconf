# ===============================================
# Zsh Completion
# ===============================================
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*' force-list always
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ===============================================
# Key Bindings
# ===============================================
bindkey '^[[1;5A' history-search-backward
bindkey '^[[1;5B' history-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ===============================================
# Television (Fuzzy Finder) shell integration
# ===============================================
eval "$(tv init zsh)" 2>/dev/null || true

# Override Ctrl+T to avoid zsh "do you wish to see all N possibilities"
# when prompt is empty - launch tv files channel instead of expand-or-complete
_tv_smart_autocomplete() {
  _disable_bracketed_paste
  local tokens prefix lbuf
  setopt localoptions noshwordsplit noksh_arrays noposixbuiltins
  tokens=(${(z)LBUFFER})
  if [ ${#tokens} -lt 1 ]; then
    local output
    output=$(tv files --no-status-bar --inline)
    zle reset-prompt
    if [[ -n $output ]]; then
      LBUFFER="${LBUFFER}${output}"
    fi
    _enable_bracketed_paste
    return
  fi
  [[ ${LBUFFER[-1]} == ' ' ]] && tokens+=("")
  if [[ ${LBUFFER} = *"${tokens[-2]-}${tokens[-1]}" ]]; then
    tokens[-2]="${tokens[-2]-}${tokens[-1]}"
    tokens=(${tokens[0,-2]})
  fi
  lbuf=$LBUFFER
  prefix=${tokens[-1]}
  [ -n "${tokens[-1]}" ] && lbuf=${lbuf:0:-${#tokens[-1]}}
  __tv_path_completion "$prefix" "$lbuf"
  _enable_bracketed_paste
}

# Override Ctrl+R history to use cable channel with dedup
_tv_shell_history() {
  emulate -L zsh
  zle -I
  _disable_bracketed_paste
  local current_prompt=$LBUFFER
  local output
  output=$(tv zsh-history --no-status-bar --input "$current_prompt" --inline)
  zle reset-prompt
  if [[ -n $output ]]; then
    RBUFFER=""
    LBUFFER="$output"
  fi
  _enable_bracketed_paste
}

zle -N _tv_smart_autocomplete
zle -N _tv_shell_history
bindkey '^T' _tv_smart_autocomplete
bindkey '^R' _tv_shell_history

# ===============================================
# Tmux Auto-Start
# ===============================================
tmux_auto_start
