#!/bin/zsh
# Keep multiple Codex logins isolated behind one installed Codex binary.

set -euo pipefail

GAF_HOME="${GAF_HOME:-$HOME/.config/ghostty-agent-forge}"
ACCOUNTS_FILE="${GAF_CODEX_ACCOUNTS_FILE:-$GAF_HOME/codex-accounts.tsv}"

usage() {
  cat <<'EOF'
usage: gaf codex <command> [args]

Commands:
  list
  status [profile|--all]
  add <profile> <codex-home> --yes
  login <profile>
  run <profile> [-- <codex args...>]
  home <profile>
  <profile> [codex args...]       Shorthand for run.

The built-in profile is: default -> ~/.codex
No command here logs out, replaces another profile, or installs another Codex binary.
EOF
}

die() {
  print -u2 -r -- "[gaf] codex: $*"
  return 1
}

normalize_home() {
  local value="$1"
  if [[ "$value" == "~" ]]; then
    value="$HOME"
  elif [[ "$value" == ~/* ]]; then
    value="$HOME/${value#~/}"
  fi
  [[ "$value" == /* ]] || { die "Codex home must be absolute or start with ~/: $1"; return 1; }
  print -r -- "${value:a}"
}

configured_home() {
  local profile="$1"
  [[ -r "$ACCOUNTS_FILE" ]] || return 1
  awk -F '\t' -v profile="$profile" '
    $0 !~ /^#/ && $1 == profile { print $2; found=1; exit }
    END { if (!found) exit 1 }
  ' "$ACCOUNTS_FILE"
}

profile_home() {
  local profile="$1" configured=""
  if configured="$(configured_home "$profile" 2>/dev/null)"; then
    normalize_home "$configured"
    return
  fi
  if [[ "$profile" == "default" ]]; then
    normalize_home "$HOME/.codex"
    return
  fi
  die "unknown profile '$profile'; add it with: gaf codex add $profile <codex-home> --yes"
}

profile_names() {
  print default
  if [[ -r "$ACCOUNTS_FILE" ]]; then
    awk -F '\t' '$0 !~ /^#/ && NF >= 2 && $1 != "default" { print $1 }' "$ACCOUNTS_FILE"
  fi
}

codex_bin() {
  local binary="${GAF_CODEX_BIN:-}"
  if [[ -z "$binary" ]]; then
    binary="$(command -v codex 2>/dev/null || true)"
  fi
  [[ -n "$binary" && -x "$binary" ]] || { die "Codex binary not found on PATH"; return 1; }
  print -r -- "${binary:A}"
}

print_binary() {
  local binary version
  binary="$(codex_bin)" || return
  version="$(cd "$HOME" && "$binary" --version 2>/dev/null | head -n 1 || true)"
  print -r -- "binary  $binary ${version:+($version)}"
}

list_profiles() {
  print_binary
  print
  printf "%-16s %-7s %s\n" "PROFILE" "STATE" "CODEX_HOME"
  local profile home state
  while IFS= read -r profile; do
    [[ -n "$profile" ]] || continue
    home="$(profile_home "$profile")" || continue
    state="missing"
    [[ -d "$home" ]] && state="present"
    printf "%-16s %-7s %s\n" "$profile" "$state" "$home"
  done < <(profile_names)
}

status_one() {
  local profile="$1" home binary output
  home="$(profile_home "$profile")" || return
  binary="$(codex_bin)" || return
  print -r -- "profile  $profile"
  print -r -- "home     $home"
  if output="$(cd "$HOME" && CODEX_HOME="$home" "$binary" login status 2>&1)"; then
    print -r -- "status   ${output//$'\n'/ }"
  else
    print -r -- "status   signed-out or unavailable"
    [[ -n "$output" ]] && print -r -- "detail   ${output//$'\n'/ }"
    return 1
  fi
}

status_profiles() {
  local target="${1:-default}" profile rc=0
  print_binary
  print
  if [[ "$target" == "--all" ]]; then
    while IFS= read -r profile; do
      [[ -n "$profile" ]] || continue
      status_one "$profile" || rc=1
      print
    done < <(profile_names)
    return "$rc"
  fi
  status_one "$target"
}

add_profile() {
  (( $# >= 2 )) || { die "usage: gaf codex add <profile> <codex-home> --yes"; return 2; }
  local profile="$1" home_arg="$2" yes=0
  shift 2
  while (( $# > 0 )); do
    case "$1" in
      --yes|-y) yes=1 ;;
      *) die "unknown add argument: $1"; return 2 ;;
    esac
    shift
  done
  [[ "$profile" =~ ^[A-Za-z0-9._-]+$ ]] || { die "profile names may contain letters, numbers, dot, underscore, and dash"; return 2; }
  [[ -n "$home_arg" ]] || { die "missing Codex home"; return 2; }
  (( yes )) || { print -r -- "Re-run with --yes to write $ACCOUNTS_FILE"; return 2; }
  [[ ! -L "$ACCOUNTS_FILE" ]] || { die "refusing to replace symlinked account registry: $ACCOUNTS_FILE"; return 1; }

  local home tmp
  home="$(normalize_home "$home_arg")" || return
  mkdir -p "${ACCOUNTS_FILE:h}"
  tmp="$(mktemp "${ACCOUNTS_FILE}.tmp.XXXXXX")"
  if [[ -r "$ACCOUNTS_FILE" ]]; then
    awk -F '\t' -v profile="$profile" '$0 ~ /^#/ || $1 != profile' "$ACCOUNTS_FILE" > "$tmp"
  else
    print -r -- $'# profile\tCODEX_HOME' > "$tmp"
  fi
  printf "%s\t%s\n" "$profile" "$home" >> "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$ACCOUNTS_FILE"
  print -r -- "configured $profile -> $home"
}

login_profile() {
  local profile="${1:-}" home binary
  [[ -n "$profile" ]] || { die "missing profile"; return 2; }
  home="$(profile_home "$profile")" || return
  binary="$(codex_bin)" || return
  mkdir -p "$home"
  print -r -- "Codex login profile: $profile"
  print -r -- "Codex home:          $home"
  print -r -- "Codex binary:        $binary"
  print -r -- "This does not log out or modify any other profile."
  cd "$HOME"
  CODEX_HOME="$home" "$binary" login --device-auth
}

run_profile() {
  local profile="${1:-}" home binary
  [[ -n "$profile" ]] || { die "missing profile"; return 2; }
  shift
  [[ "${1:-}" == "--" ]] && shift
  home="$(profile_home "$profile")" || return
  binary="$(codex_bin)" || return
  if ! /bin/ls -A . >/dev/null 2>&1; then
    print -u2 -r -- "[gaf] codex: current directory is unreadable; starting from $HOME"
    cd "$HOME"
  fi
  exec env CODEX_HOME="$home" "$binary" "$@"
}

subcommand="${1:-}"
shift || true
case "$subcommand" in
  list) list_profiles "$@" ;;
  status) status_profiles "$@" ;;
  add) add_profile "$@" ;;
  login) login_profile "$@" ;;
  run) run_profile "$@" ;;
  home)
    [[ $# == 1 ]] || { die "usage: gaf codex home <profile>"; exit 2; }
    profile_home "$1"
    ;;
  -h|--help|"") usage ;;
  *)
    profile_home "$subcommand" >/dev/null 2>&1 || { usage; exit 2; }
    run_profile "$subcommand" "$@"
    ;;
esac
