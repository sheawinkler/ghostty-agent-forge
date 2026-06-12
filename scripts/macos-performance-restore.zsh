#!/bin/zsh
# Reapply the low-noise macOS workstation profile after OS updates.

set -euo pipefail

ACTION="${1:-status}"
shift || true

APPLY=0
SYSTEM=0
LOAD_AGENT=0

usage() {
  cat <<'EOF'
usage: macos-performance-restore.zsh <status|restore|install-agent|uninstall-agent> [options]

Commands:
  status               Print current power, Spotlight, launchd, Codex CLI, and path state.
  restore              Reapply safe user-level settings. Dry-run unless --yes is passed.
  install-agent        Install a low-priority user LaunchAgent to run restore at login/daily.
  uninstall-agent      Remove the user LaunchAgent.

Options:
  --yes                Apply user-level changes.
  --system             Also attempt sudo-required pmset and Spotlight changes.
  --load               Load/kickstart the LaunchAgent after installing it.

Notes:
  restore --yes does not use sudo. It disables selected user LaunchAgents.

  restore --yes --system may prompt for your password and applies machine-level
  power and Spotlight settings.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --yes|-y) APPLY=1 ;;
    --system) SYSTEM=1 ;;
    --load) LOAD_AGENT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 -- "unknown argument: $1"; usage; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 -- "macos-performance-restore is macOS-only."
  exit 1
fi

USER_ID="$(id -u)"
GAF_HOME="${GAF_HOME:-$HOME/.config/ghostty-agent-forge}"
GAF_STATE_DIR="${GAF_STATE_DIR:-$HOME/.local/state/ghostty-agent-forge}"
AGENT_LABEL="com.contextlattice.ghostty-agent-forge.macos-restore"
AGENT_INTERVAL_SECS="${GAF_MACOS_RESTORE_INTERVAL_SECS:-86400}"

USER_LAUNCH_LABELS=(
  com.apple.weather.menu
  com.apple.Siri.agent
  com.apple.photoanalysisd
  com.apple.photolibraryd
  com.apple.cloudphotod
  com.apple.mediaanalysisd
)

log() {
  print -r -- "[macos-restore] $*"
}

warn() {
  print -u2 -r -- "[macos-restore] warn: $*"
}

print_check() {
  local check_status="$1"
  local label="$2"
  local value="${3:-}"
  printf "%-8s %-32s %s\n" "$check_status" "$label" "$value"
}

label_disabled_line() {
  local label="$1"
  launchctl print-disabled "gui/${USER_ID}" 2>/dev/null | grep -F "\"${label}\"" || true
}

label_is_disabled() {
  local label="$1"
  label_disabled_line "$label" | grep -q '=> disabled'
}

run_user() {
  if (( APPLY )); then
    log "+ $*"
    "$@"
  else
    print -r -- "would: $*"
  fi
}

sudo_or_print() {
  if (( APPLY && SYSTEM )); then
    log "+ sudo $*"
    if ! sudo "$@"; then
      warn "command failed: sudo $*"
    fi
  else
    print -r -- "sudo-needed: sudo $*"
  fi
}

disable_user_label() {
  local label="$1"
  run_user launchctl disable "gui/${USER_ID}/${label}" 2>/dev/null || true
  if (( APPLY )); then
    launchctl bootout "gui/${USER_ID}/${label}" >/dev/null 2>&1 || true
  else
    print -r -- "would: launchctl bootout gui/${USER_ID}/${label}"
  fi
}

print_system_restore_commands() {
  print
  print "System-level restore commands"
  sudo_or_print pmset -a powermode 2
  sudo_or_print pmset -c sleep 0 displaysleep 60 disksleep 10
  sudo_or_print pmset -b sleep 30 displaysleep 3 disksleep 10
  sudo_or_print mdutil -i off /System/Volumes/Data
  sudo_or_print mdutil -i off /
}

status() {
  print "macOS performance restore status"
  print

  print "System"
  print_check "info" "macOS" "$(sw_vers -productVersion 2>/dev/null) ($(sw_vers -buildVersion 2>/dev/null))"
  print_check "info" "user" "$(id -un) uid=${USER_ID}"

  print
  print "Power"
  pmset -g custom 2>/dev/null | sed -n '1,80p' || print_check "warn" "pmset" "unavailable"

  print
  print "Spotlight"
  mdutil -a -s 2>/dev/null || print_check "warn" "mdutil" "unavailable"

  print
  print "Low-noise LaunchAgents"
  local label line
  for label in "${USER_LAUNCH_LABELS[@]}"; do
    line="$(label_disabled_line "$label")"
    if [[ -n "$line" ]]; then
      print_check "info" "$label" "$line"
    else
      print_check "unknown" "$label" "no disabled override"
    fi
  done

  print
  print "Restore LaunchAgent"
  local plist="${HOME}/Library/LaunchAgents/${AGENT_LABEL}.plist"
  if [[ -f "$plist" ]]; then
    print_check "ok" "$AGENT_LABEL" "$plist"
  else
    print_check "missing" "$AGENT_LABEL" "$plist"
  fi
  if launchctl print "gui/${USER_ID}/${AGENT_LABEL}" >/dev/null 2>&1; then
    print_check "ok" "launchd_loaded" "$AGENT_LABEL"
  else
    print_check "missing" "launchd_loaded" "$AGENT_LABEL"
  fi

  print
  print "Codex CLI"
  local codex_path codex_version
  codex_path="$(command -v codex 2>/dev/null || true)"
  if [[ -n "$codex_path" ]]; then
    codex_version="$("$codex_path" --version 2>/dev/null | head -n 1 || true)"
    print_check "ok" "codex" "${codex_path} ${codex_version}"
  else
    print_check "missing" "codex" "not found"
  fi

  print
  print "Path/TCC probes"
  local probe
  for probe in "$HOME" "$HOME/Documents" "$HOME/Downloads" /Volumes/wd_black; do
    [[ -e "$probe" ]] || continue
    if /bin/ls "$probe" >/dev/null 2>&1; then
      print_check "ok" "$probe" "readable"
    else
      print_check "blocked" "$probe" "macOS privacy or Unix permissions"
    fi
  done

  if command -v codex-perms-doctor >/dev/null 2>&1; then
    print
    codex-perms-doctor
  fi
}

restore() {
  print "macOS performance restore"
  if (( ! APPLY )); then
    print "mode: dry-run. Re-run with --yes to apply user-level changes."
  elif (( SYSTEM )); then
    print "mode: applying user-level and sudo-required system changes."
  else
    print "mode: applying user-level changes only."
  fi
  print

  print "Low-noise LaunchAgents"
  local label
  for label in "${USER_LAUNCH_LABELS[@]}"; do
    if label_is_disabled "$label"; then
      print_check "ok" "$label" "already disabled"
    else
      disable_user_label "$label"
    fi
  done

  print_system_restore_commands

  print
  print "Verification command:"
  print "  gaf macos status"
}

install_agent() {
  local launch_dir="${HOME}/Library/LaunchAgents"
  local plist="${launch_dir}/${AGENT_LABEL}.plist"
  local restore_script="${GAF_HOME}/scripts/macos-performance-restore.zsh"
  [[ -x "$restore_script" ]] || restore_script="${0:A}"

  if (( ! APPLY )); then
    print "mode: dry-run. Re-run with --yes to install the LaunchAgent."
    print "would: write $plist"
    print "would: run $restore_script restore --yes at login and every ${AGENT_INTERVAL_SECS}s"
    return 0
  fi

  mkdir -p "$launch_dir" "$GAF_STATE_DIR"
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${AGENT_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${restore_script}</string>
    <string>restore</string>
    <string>--yes</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>GAF_HOME</key>
    <string>${GAF_HOME}</string>
    <key>GAF_STATE_DIR</key>
    <string>${GAF_STATE_DIR}</string>
    <key>PATH</key>
    <string>${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>${AGENT_INTERVAL_SECS}</integer>
  <key>LowPriorityIO</key>
  <true/>
  <key>Nice</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>${GAF_STATE_DIR}/macos-restore.out</string>
  <key>StandardErrorPath</key>
  <string>${GAF_STATE_DIR}/macos-restore.err</string>
</dict>
</plist>
EOF
  plutil -lint "$plist" >/dev/null
  log "installed $plist"

  if (( LOAD_AGENT )); then
    launchctl bootout "gui/${USER_ID}" "$plist" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/${USER_ID}" "$plist"
    launchctl kickstart -k "gui/${USER_ID}/${AGENT_LABEL}" >/dev/null 2>&1 || true
    log "loaded $AGENT_LABEL"
  fi
}

uninstall_agent() {
  local plist="${HOME}/Library/LaunchAgents/${AGENT_LABEL}.plist"
  if (( ! APPLY )); then
    print "mode: dry-run. Re-run with --yes to remove the LaunchAgent."
    print "would: unload and remove $plist"
    return 0
  fi
  launchctl bootout "gui/${USER_ID}" "$plist" >/dev/null 2>&1 || true
  rm -f "$plist"
  log "removed $plist"
}

case "$ACTION" in
  status) status ;;
  restore) restore ;;
  install-agent) install_agent ;;
  uninstall-agent) uninstall_agent ;;
  -h|--help) usage ;;
  *) print -u2 -- "unknown command: $ACTION"; usage; exit 2 ;;
esac
