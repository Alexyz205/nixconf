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

# Ctrl+T: guess the channel from the current prompt (channel_triggers config)
_tv_smart_autocomplete() {
  _disable_bracketed_paste
  local output
  output=$(tv --autocomplete-prompt "$LBUFFER" --inline --no-status-bar)
  zle reset-prompt
  if [[ -n $output ]]; then
    RBUFFER=""
    LBUFFER="$output"
  fi
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
