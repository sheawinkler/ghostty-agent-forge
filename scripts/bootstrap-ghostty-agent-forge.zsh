#!/bin/zsh
# Bootstrap Ghostty Agent Forge on macOS.

set -euo pipefail

DRY_RUN=0
INSTALL_HOMEBREW=0
INSTALL_GHOSTTY=1
INSTALL_OH_MY_ZSH=1
INSTALL_CONTEXTLATTICE=0
INSTALL_RESOURCE_TOOLS=0
CONTEXTLATTICE_PROMPT=1
CONTEXTLATTICE_REPO_URL="${CONTEXTLATTICE_REPO_URL:-https://github.com/sheawinkler/ContextLattice.git}"
CONTEXTLATTICE_DIR="${CONTEXTLATTICE_DIR:-$HOME/Documents/Projects/ContextLattice}"
CONFIG_ROOT="${CONFIG_ROOT:-$HOME/.config/ghostty-agent-forge}"

usage() {
  cat <<'EOF'
usage: bootstrap-ghostty-agent-forge.zsh [options]

Options:
  --dry-run                    Print intended actions.
  --install-homebrew           Install Homebrew if missing.
  --no-ghostty                 Skip Ghostty cask install.
  --no-oh-my-zsh               Skip Oh My Zsh install.
  --install-contextlattice     Clone the public ContextLattice repo.
  --resource-tools             Install resource ops formulae for heavy local workloads.
  --no-contextlattice-prompt   Do not prompt for ContextLattice install.
  --contextlattice-dir <path>  Clone ContextLattice into this path.

Default behavior installs the terminal stack, backs up shell files, writes
modular zsh config, and prompts before cloning ContextLattice.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --install-homebrew) INSTALL_HOMEBREW=1 ;;
    --no-ghostty) INSTALL_GHOSTTY=0 ;;
    --no-oh-my-zsh) INSTALL_OH_MY_ZSH=0 ;;
    --install-contextlattice) INSTALL_CONTEXTLATTICE=1 ;;
    --resource-tools) INSTALL_RESOURCE_TOOLS=1 ;;
    --no-contextlattice-prompt) CONTEXTLATTICE_PROMPT=0 ;;
    --contextlattice-dir)
      shift
      CONTEXTLATTICE_DIR="${1:-}"
      [[ -n "$CONTEXTLATTICE_DIR" ]] || { print -u2 -- "missing path for --contextlattice-dir"; exit 2; }
      ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 -- "unknown argument: $1"; usage; exit 2 ;;
  esac
  shift
done

log() {
  print -r -- "[ghostty-agent-forge] $*"
}

run() {
  if (( DRY_RUN )); then
    print -r -- "+ $*"
  else
    "$@"
  fi
}

write_file() {
  local target="$1"
  local source="$2"
  if (( DRY_RUN )); then
    log "would write $target"
  else
    mkdir -p "${target:h}"
    cp "$source" "$target"
  fi
}

remove_managed_block() {
  local file="$1"
  local start="$2"
  local end="$3"
  [[ -f "$file" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$file" > "$tmp"
  if (( DRY_RUN )); then
    log "would remove managed block $start from $file"
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi
}

prepend_block() {
  local file="$1"
  local block="$2"
  local tmp
  tmp="$(mktemp)"
  {
    cat "$block"
    print
    [[ -f "$file" ]] && cat "$file"
  } > "$tmp"
  if (( DRY_RUN )); then
    log "would prepend managed block to $file"
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi
}

append_block() {
  local file="$1"
  local block="$2"
  local tmp
  tmp="$(mktemp)"
  {
    [[ -f "$file" ]] && cat "$file"
    print
    cat "$block"
  } > "$tmp"
  if (( DRY_RUN )); then
    log "would append managed block to $file"
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi
}

insert_after_omz() {
  local file="$1"
  local pre="$2"
  local post="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v pre="$pre" -v post="$post" '
    BEGIN {
      while ((getline line < pre) > 0) pretext = pretext line ORS
      close(pre)
      while ((getline line < post) > 0) posttext = posttext line ORS
      close(post)
    }
    !inserted && $0 ~ /oh-my-zsh\.sh/ {
      printf "%s", pretext
      print
      printf "%s", posttext
      inserted = 1
      next
    }
    { print }
    END {
      if (!inserted) {
        printf "%s", pretext
        print "[[ -r \"$ZSH/oh-my-zsh.sh\" ]] && source \"$ZSH/oh-my-zsh.sh\""
        printf "%s", posttext
      }
    }
  ' "$file" > "$tmp"
  if (( DRY_RUN )); then
    log "would insert Oh My Zsh managed blocks into $file"
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi
}

clone_contextlattice() {
  if [[ -d "$CONTEXTLATTICE_DIR/.git" ]]; then
    log "ContextLattice already exists at $CONTEXTLATTICE_DIR"
    return 0
  fi
  run mkdir -p "${CONTEXTLATTICE_DIR:h}"
  run git clone "$CONTEXTLATTICE_REPO_URL" "$CONTEXTLATTICE_DIR"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 -- "Ghostty Agent Forge bootstrap is currently macOS-only."
  exit 1
fi

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="$HOME/.zsh_backups/ghostty-agent-forge-$STAMP"

run mkdir -p "$BACKUP_DIR" "$CONFIG_ROOT/bin" "$CONFIG_ROOT/config" "$CONFIG_ROOT/scripts" "$CONFIG_ROOT/zsh" "$HOME/.cache/zsh" "$HOME/.local/bin"
[[ -f "$HOME/.zprofile" ]] && run cp -p "$HOME/.zprofile" "$BACKUP_DIR/.zprofile"
[[ -f "$HOME/.zshrc" ]] && run cp -p "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"

if ! command -v brew >/dev/null 2>&1; then
  if (( INSTALL_HOMEBREW )); then
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    print -u2 -- "Homebrew is required. Re-run with --install-homebrew or install it first."
    exit 1
  fi
fi

eval "$(
  (cd "$HOME" && brew shellenv) 2>/dev/null
)"

FORMULAE=(
  spaceship
  fzf
  fzf-tab
  zsh-autosuggestions
  zsh-syntax-highlighting
  zoxide
  direnv
  fd
  ripgrep
  docker
  jq
  gh
)

RESOURCE_FORMULAE=(
  btop
  procs
  smartmontools
  dust
  dua-cli
  dysk
  ncdu
  gdu
  rclone
  restic
  watchman
  hyperfine
  yq
)

run brew install "${FORMULAE[@]}"
if (( INSTALL_RESOURCE_TOOLS )); then
  run brew install "${RESOURCE_FORMULAE[@]}"
fi

if (( INSTALL_GHOSTTY )) && [[ ! -d /Applications/Ghostty.app ]]; then
  run brew install --cask ghostty
fi

if (( INSTALL_OH_MY_ZSH )) && [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

for module in completion post-omz contextlattice tools prompt-spaceship late-widgets; do
  write_file "$CONFIG_ROOT/zsh/$module.zsh" "$REPO_ROOT/zsh/$module.zsh"
done
for completion in "$REPO_ROOT"/zsh/completions/_*; do
  [[ -e "$completion" ]] || continue
  write_file "$CONFIG_ROOT/zsh/completions/${completion:t}" "$completion"
done

write_file "$CONFIG_ROOT/bin/gaf" "$REPO_ROOT/bin/gaf"
write_file "$CONFIG_ROOT/VERSION" "$REPO_ROOT/VERSION"
write_file "$CONFIG_ROOT/agent-runtime.json" "$REPO_ROOT/config/agent-runtime.json"
for helper in bootstrap-ghostty-agent-forge contextlattice-preflight macos-tcc-doctor macos-performance-restore claude-permissions codex-accounts self-update; do
  write_file "$CONFIG_ROOT/scripts/$helper.zsh" "$REPO_ROOT/scripts/$helper.zsh"
done
for helper in behavior-pack agent-harnesses; do
  write_file "$CONFIG_ROOT/scripts/$helper.py" "$REPO_ROOT/scripts/$helper.py"
done
run chmod +x \
  "$CONFIG_ROOT/bin/gaf" \
  "$CONFIG_ROOT/scripts/bootstrap-ghostty-agent-forge.zsh" \
  "$CONFIG_ROOT/scripts/contextlattice-preflight.zsh" \
  "$CONFIG_ROOT/scripts/macos-tcc-doctor.zsh" \
  "$CONFIG_ROOT/scripts/macos-performance-restore.zsh" \
  "$CONFIG_ROOT/scripts/claude-permissions.zsh" \
  "$CONFIG_ROOT/scripts/codex-accounts.zsh" \
  "$CONFIG_ROOT/scripts/self-update.zsh" \
  "$CONFIG_ROOT/scripts/behavior-pack.py" \
  "$CONFIG_ROOT/scripts/agent-harnesses.py"
run ln -sf "$CONFIG_ROOT/bin/gaf" "$HOME/.local/bin/gaf"

touch "$HOME/.zprofile" "$HOME/.zshrc"

tmp_profile="$(mktemp)"
cat > "$tmp_profile" <<'EOF'
# >>> ghostty-agent-forge profile >>>
if ! /bin/ls -A . >/dev/null 2>&1; then
  builtin cd "$HOME" 2>/dev/null || true
fi

export PATH="$HOME/.local/bin:$PATH"
umask 022

export HOMEBREW_AUTO_UPDATE_SECS="${HOMEBREW_AUTO_UPDATE_SECS:-86400}"
export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"

if [[ -d "$HOME/.orbstack/bin" ]]; then
  export PATH="$HOME/.orbstack/bin:$PATH"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(
    (cd "$HOME" && /opt/homebrew/bin/brew shellenv) 2>/dev/null
  )"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(
    (cd "$HOME" && /usr/local/bin/brew shellenv) 2>/dev/null
  )"
fi

source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null || true
# <<< ghostty-agent-forge profile <<<
EOF

remove_managed_block "$HOME/.zprofile" "# >>> ghostty-agent-forge profile >>>" "# <<< ghostty-agent-forge profile <<<"
prepend_block "$HOME/.zprofile" "$tmp_profile"
rm -f "$tmp_profile"

remove_managed_block "$HOME/.zshrc" "# >>> ghostty-agent-forge pre-omz >>>" "# <<< ghostty-agent-forge pre-omz <<<"
remove_managed_block "$HOME/.zshrc" "# >>> ghostty-agent-forge post-omz >>>" "# <<< ghostty-agent-forge post-omz <<<"
remove_managed_block "$HOME/.zshrc" "# >>> ghostty-agent-forge final >>>" "# <<< ghostty-agent-forge final <<<"

if (( ! DRY_RUN )); then
  perl -0pi -e 's/\nif \[\[ -t 0 && -t 1 \]\]; then\n\s*plugins\+\=\(fzf\)\nfi\n/\n# disabled by ghostty-agent-forge: OMZ fzf plugin replaced by fzf-tab and explicit fzf setup\n/s' "$HOME/.zshrc"
  perl -pi -e 's/^(\s*ZSH_THEME=.*)$/# disabled by ghostty-agent-forge: $1/' "$HOME/.zshrc"
  perl -pi -e 's/^(\s*plugins=.*)$/# disabled by ghostty-agent-forge: $1/' "$HOME/.zshrc"
  perl -pi -e 's/^(\s*\[\s*-s "\$NVM_DIR\/nvm\.sh" \].*)$/# disabled by ghostty-agent-forge lazy nvm: $1/' "$HOME/.zshrc"
  perl -pi -e 's/^(\s*\[\s*-s "\$NVM_DIR\/bash_completion" \].*)$/# disabled by ghostty-agent-forge lazy nvm: $1/' "$HOME/.zshrc"
fi

tmp_pre="$(mktemp)"
cat > "$tmp_pre" <<EOF
# >>> ghostty-agent-forge pre-omz >>>
typeset -U path PATH fpath FPATH
path=(\$HOME/.local/bin /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /usr/local/sbin /usr/bin /bin /usr/sbin /sbin \$path)
export PATH
export ZSH="\${ZSH:-\$HOME/.oh-my-zsh}"
ZSH_THEME=""
plugins=(git)
[[ -r "$CONFIG_ROOT/zsh/completion.zsh" ]] && source "$CONFIG_ROOT/zsh/completion.zsh"
# <<< ghostty-agent-forge pre-omz <<<
EOF

tmp_post="$(mktemp)"
cat > "$tmp_post" <<EOF
# >>> ghostty-agent-forge post-omz >>>
[[ -r "$CONFIG_ROOT/zsh/post-omz.zsh" ]] && source "$CONFIG_ROOT/zsh/post-omz.zsh"
# <<< ghostty-agent-forge post-omz <<<
EOF

insert_after_omz "$HOME/.zshrc" "$tmp_pre" "$tmp_post"
rm -f "$tmp_pre" "$tmp_post"

tmp_final="$(mktemp)"
cat > "$tmp_final" <<EOF
# >>> ghostty-agent-forge final >>>
[[ -r "$CONFIG_ROOT/zsh/contextlattice.zsh" ]] && source "$CONFIG_ROOT/zsh/contextlattice.zsh"
[[ -r "$CONFIG_ROOT/zsh/tools.zsh" ]] && source "$CONFIG_ROOT/zsh/tools.zsh"
[[ -r "$CONFIG_ROOT/zsh/prompt-spaceship.zsh" ]] && source "$CONFIG_ROOT/zsh/prompt-spaceship.zsh"
typeset -U path PATH fpath FPATH
[[ -r "$CONFIG_ROOT/zsh/late-widgets.zsh" ]] && source "$CONFIG_ROOT/zsh/late-widgets.zsh"
# <<< ghostty-agent-forge final <<<
EOF
append_block "$HOME/.zshrc" "$tmp_final"
rm -f "$tmp_final"

if (( ! DRY_RUN )); then
  mkdir -p "$BACKUP_DIR/zcompdump"
  for f in "$HOME"/.zcompdump*(N); do
    mv "$f" "$BACKUP_DIR/zcompdump/"
  done
fi

if (( INSTALL_CONTEXTLATTICE )); then
  clone_contextlattice
elif (( CONTEXTLATTICE_PROMPT )) && [[ -t 0 && -t 1 && ! -d "$CONTEXTLATTICE_DIR/.git" ]]; then
  print
  print -r -- "Install the free public ContextLattice repo for local memory hooks?"
  print -r -- "  $CONTEXTLATTICE_REPO_URL"
  printf "Clone into %s? [y/N] " "$CONTEXTLATTICE_DIR"
  read -r reply
  case "$reply" in
    y|Y|yes|YES) clone_contextlattice ;;
    *) log "skipping ContextLattice clone" ;;
  esac
fi

run zsh -n "$HOME/.zshrc"
for file in "$CONFIG_ROOT"/zsh/*.zsh(N); do
  run zsh -n "$file"
done

if (( ! DRY_RUN )); then
  zsh -ic 'print START_OK; print SPACESHIP_VERSION=${SPACESHIP_VERSION:-unset}; whence -w _brew _docker _cargo _uv _pnpm _rg _fd _gh _zoxide 2>/dev/null || true'
  zsh -ic 'autoload -Uz compaudit; compaudit 2>&1 || true'
  for i in 1 2 3; do
    /usr/bin/time -p zsh -ic exit >/tmp/ghostty-agent-forge-startup.out 2>/tmp/ghostty-agent-forge-startup.err || true
    print -r -- "startup_run=$i $(tr '\n' ' ' < /tmp/ghostty-agent-forge-startup.err)"
  done
  rm -f /tmp/ghostty-agent-forge-startup.out /tmp/ghostty-agent-forge-startup.err
fi

log "complete"
log "backup dir: $BACKUP_DIR"
log "restart current shell with: exec zsh -l"
