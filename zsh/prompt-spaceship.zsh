# Homebrew-managed Spaceship prompt. Keep this narrower than the default section set.
# `zsh -lic` is interactive even without a terminal. Do not start prompt workers
# in headless agent/bootstrap shells, where teardown can turn a valid command
# into a false failure under `set -u`.

if [[ -o interactive && -t 0 && -t 1 ]]; then
  export SPACESHIP_PROMPT_ASYNC="${SPACESHIP_PROMPT_ASYNC:-true}"
  export SPACESHIP_PROMPT_ADD_NEWLINE="${SPACESHIP_PROMPT_ADD_NEWLINE:-false}"
  export SPACESHIP_PROMPT_SEPARATE_LINE="${SPACESHIP_PROMPT_SEPARATE_LINE:-true}"
  export SPACESHIP_TIME_SHOW="${SPACESHIP_TIME_SHOW:-true}"
  export SPACESHIP_EXEC_TIME_SHOW="${SPACESHIP_EXEC_TIME_SHOW:-true}"
  export SPACESHIP_EXEC_TIME_ELAPSED="${SPACESHIP_EXEC_TIME_ELAPSED:-2}"
  export SPACESHIP_GIT_STATUS_SHOW="${SPACESHIP_GIT_STATUS_SHOW:-true}"
  export SPACESHIP_PACKAGE_SHOW="${SPACESHIP_PACKAGE_SHOW:-false}"

  SPACESHIP_PROMPT_ORDER=(
    time
    dir
    git
    node
    python
    golang
    rust
    docker
    aws
    gcloud
    uv
    exec_time
    line_sep
    jobs
    exit_code
    char
  )

  SPACESHIP_RPROMPT_ORDER=()

  if [[ -r /opt/homebrew/opt/spaceship/spaceship.zsh ]]; then
    source /opt/homebrew/opt/spaceship/spaceship.zsh
  fi
fi
