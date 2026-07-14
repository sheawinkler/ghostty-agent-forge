# Lightweight interactive tool hooks. Keep expensive runtimes lazy.
# Headless login shells still need PATH and helper functions, but must not run
# cwd-triggered hooks such as direnv or initialize terminal-only navigation.

if [[ -o interactive && -t 0 && -t 1 ]]; then
  if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
  fi

  if (( $+commands[direnv] )); then
    eval "$(direnv hook zsh)"
  fi
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
