# Lightweight interactive tool hooks. Keep expensive runtimes lazy.

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
nvm() {
  unset -f nvm 2>/dev/null || true
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    nvm "$@"
  else
    print -u2 -- "nvm not found at $NVM_DIR/nvm.sh"
    return 127
  fi
}

