#!/bin/zsh
# Update the installed public forge from a verified Git checkout.

set -euo pipefail

CURRENT_VERSION="${GAF_VERSION:-unknown}"
DEFAULT_REPO="${GAF_PUBLIC_REPO:-sheawinkler/ghostty-agent-forge}"
DEFAULT_REF="${GAF_PUBLIC_REF:-main}"

usage() {
  cat <<'EOF'
usage: gaf self <status|update> [options]

  self status
  self update [--yes|--dry-run] [--repo owner/repo] [--ref branch-or-tag]

The updater clones into a temporary directory and runs the checked-out bootstrap.
It will not downgrade or update from a checkout whose VERSION is unchanged.
EOF
}

version_at_least() {
  python3 - "$1" "$2" <<'PY'
import re, sys
def parse(value):
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", value)
    if not match:
        raise SystemExit(2)
    return tuple(map(int, match.groups()))
raise SystemExit(0 if parse(sys.argv[1]) >= parse(sys.argv[2]) else 1)
PY
}

self_status() {
  print -r -- "Ghostty Agent Forge self status"
  print -r -- "version  $CURRENT_VERSION"
  print -r -- "binary   ${GAF_CALLER_BIN:-${0:A}}"
  print -r -- "repo     $DEFAULT_REPO"
  print -r -- "ref      $DEFAULT_REF"
}

self_update() {
  local yes=0 dry_run=0 repo="$DEFAULT_REPO" ref="$DEFAULT_REF"
  while (( $# > 0 )); do
    case "$1" in
      --yes|-y) yes=1 ;;
      --dry-run) dry_run=1 ;;
      --repo)
        shift
        repo="${1:-}"
        [[ -n "$repo" ]] || { print -u2 -- "missing owner/repo for --repo"; return 2; }
        ;;
      --ref)
        shift
        ref="${1:-}"
        [[ -n "$ref" ]] || { print -u2 -- "missing branch or tag for --ref"; return 2; }
        ;;
      *) print -u2 -- "unknown self update argument: $1"; return 2 ;;
    esac
    shift
  done
  if (( dry_run )); then
    print -r -- "would clone $repo at $ref into a temporary directory"
    print -r -- "would require a VERSION newer than $CURRENT_VERSION"
    print -r -- "would run the checked-out bootstrap without app or ContextLattice prompts"
    return 0
  fi
  (( yes )) || { print -r -- "Re-run with --yes to update Ghostty Agent Forge."; return 2; }
  command -v gh >/dev/null 2>&1 || { print -u2 -- "gh is required for self update"; return 1; }
  command -v python3 >/dev/null 2>&1 || { print -u2 -- "python3 is required for self update"; return 1; }

  local tmp checkout next_version installed_version
  tmp="$(mktemp -d)"
  trap "rm -rf -- '$tmp'" EXIT INT TERM
  checkout="$tmp/ghostty-agent-forge"
  cd "$HOME"
  gh repo clone "$repo" "$checkout" -- --depth 1 --branch "$ref"
  [[ -r "$checkout/VERSION" ]] || { print -u2 -- "downloaded checkout has no VERSION file"; return 1; }
  next_version="$(<"$checkout/VERSION")"
  version_at_least "$next_version" "$CURRENT_VERSION" || {
    print -u2 -- "refusing downgrade: installed $CURRENT_VERSION, checkout $next_version"
    return 1
  }
  if [[ "$next_version" == "$CURRENT_VERSION" ]]; then
    print -r -- "Ghostty Agent Forge is already current at $CURRENT_VERSION."
    return 0
  fi
  zsh "$checkout/scripts/bootstrap-ghostty-agent-forge.zsh" \
    --no-ghostty \
    --no-oh-my-zsh \
    --no-contextlattice-prompt
  installed_version="$(cd "$HOME" && "$HOME/.local/bin/gaf" version)"
  [[ "$installed_version" == "$next_version" ]] || {
    print -u2 -- "installed version mismatch: expected $next_version, got $installed_version"
    return 1
  }
  print -r -- "Updated Ghostty Agent Forge: $CURRENT_VERSION -> $installed_version"
}

subcommand="${1:-}"
shift || true
case "$subcommand" in
  status) self_status "$@" ;;
  update) self_update "$@" ;;
  -h|--help|"") usage ;;
  *) usage; exit 2 ;;
esac
