#!/bin/zsh
set -euo pipefail

SERVICE_URLS=(
  "full-disk-access:x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  "files-and-folders:x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
  "accessibility:x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  "automation:x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
  "developer-tools:x-apple.systempreferences:com.apple.preference.security?Privacy_DeveloperTools"
  "microphone:x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
  "camera:x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
)

usage() {
  cat <<'USAGE'
usage: macos-tcc-doctor.zsh [status|targets|panes|open <pane>|guide]

Subcommands:
  status                 Probe protected paths and likely responsible processes.
  targets                Print apps/binaries that may need manual macOS privacy grants.
  panes                  List supported Privacy & Security pane shortcuts.
  open <pane>            Open a Privacy & Security pane.
  guide                  Explain what GAF can and cannot automate.

Pane names:
  full-disk-access, files-and-folders, accessibility, automation,
  developer-tools, microphone, camera
USAGE
}

print_check() {
  local check_status="$1" label="$2" value="${3:-}"
  printf "%-8s %-32s %s\n" "$check_status" "$label" "$value"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pane_url() {
  local name="$1" entry
  for entry in "${SERVICE_URLS[@]}"; do
    if [[ "${entry%%:*}" == "$name" ]]; then
      print -r -- "${entry#*:}"
      return 0
    fi
  done
  return 1
}

check_path() {
  local label="$1" target_path="$2"
  [[ -e "$target_path" ]] || { print_check "missing" "$label" "$target_path"; return 0; }
  if /bin/ls "$target_path" >/dev/null 2>&1; then
    print_check "ok" "$label" "$target_path"
  else
    print_check "blocked" "$label" "$target_path"
  fi
}

check_python_path() {
  local label="$1" target_path="$2"
  have_cmd python3 || return 0
  [[ -e "$target_path" ]] || return 0
  if PATH_TO_CHECK="$target_path" python3 - <<'PY' >/dev/null 2>&1
import os
path = os.environ["PATH_TO_CHECK"]
os.listdir(path)
PY
  then
    print_check "ok" "python:$label" "$target_path"
  else
    print_check "blocked" "python:$label" "$target_path"
  fi
}

app_target() {
  local label="$1" app_path="$2" services="$3"
  if [[ -e "$app_path" ]]; then
    print_check "app" "$label" "$app_path | $services"
  fi
}

binary_target() {
  local cmd="$1" services="$2" bin_path=""
  bin_path="$(command -v "$cmd" 2>/dev/null || true)"
  [[ -n "$bin_path" ]] || return 0
  print_check "binary" "$cmd" "$bin_path | $services"
}

status() {
  echo "Ghostty Agent Forge macOS TCC doctor"
  echo
  print_check "info" "rule" "GAF cannot silently grant TCC/FDA; macOS requires user approval or MDM PPPC."
  print_check "info" "safe_action" "Use targets + open panes; do not edit TCC.db or chmod/chown privacy failures."
  local volume_path
  echo
  echo "Path probes"
  check_path "home" "$HOME"
  check_path "documents" "$HOME/Documents"
  check_path "desktop" "$HOME/Desktop"
  check_path "downloads" "$HOME/Downloads"
  if [[ -d /Volumes ]]; then
    for volume_path in /Volumes/*(N); do
      [[ "$volume_path" == "/Volumes/Macintosh HD" ]] && continue
      check_path "volume" "$volume_path"
    done
  fi
  echo
  echo "Python path probes"
  check_python_path "documents" "$HOME/Documents"
  check_python_path "downloads" "$HOME/Downloads"
  if [[ -d /Volumes ]]; then
    for volume_path in /Volumes/*(N); do
      [[ "$volume_path" == "/Volumes/Macintosh HD" ]] && continue
      check_python_path "volume" "$volume_path"
    done
  fi
  echo
  echo "Responsible process hints"
  print_check "info" "parent" "${PPID:-unknown}"
  ps -p "${PPID:-0}" -o pid=,ppid=,comm= 2>/dev/null | sed 's/^/process  parent_process              /' || true
  targets
}

targets() {
  echo "Permission targets"
  echo
  echo "Apps to grant when they launch agents or UI automation"
  app_target "Ghostty" "/Applications/Ghostty.app" "Full Disk Access; Files & Folders"
  app_target "Codex" "/Applications/Codex.app" "Full Disk Access; Accessibility if using Computer Use; Automation if prompted"
  app_target "ChatGPT" "/Applications/ChatGPT.app" "Full Disk Access only if it launches local tools; Accessibility/Automation if prompted"
  app_target "Visual Studio Code" "/Applications/Visual Studio Code.app" "Full Disk Access if it launches terminals/agents"
  app_target "Cursor" "/Applications/Cursor.app" "Full Disk Access if it launches terminals/agents"
  app_target "Windsurf" "/Applications/Windsurf.app" "Full Disk Access if it launches terminals/agents"
  app_target "Terminal" "/System/Applications/Utilities/Terminal.app" "Full Disk Access if used as an agent launcher"
  app_target "iTerm" "/Applications/iTerm.app" "Full Disk Access if used as an agent launcher"
  app_target "Granola" "/Applications/Granola.app" "Microphone; Accessibility only if prompted"
  echo
  echo "CLI binaries to add only if macOS names that binary in the prompt"
  binary_target "python3" "Full Disk Access or Files & Folders if prompt says Python/Python3"
  binary_target "zsh" "Full Disk Access only if shell binary is named in prompt"
  binary_target "codex" "Full Disk Access if prompt names Codex CLI rather than Codex.app/Ghostty"
  binary_target "claude" "Full Disk Access if prompt names Claude CLI"
  binary_target "opencode" "Full Disk Access if prompt names OpenCode"
  binary_target "gemini" "Full Disk Access if prompt names Gemini CLI"
  binary_target "brew" "Usually should not need FDA; add only if prompt names Homebrew while accessing protected paths"
  binary_target "gh" "Usually should not need FDA; add only if prompt names GitHub CLI while accessing protected paths"
}

panes() {
  local entry
  for entry in "${SERVICE_URLS[@]}"; do
    printf "%-18s %s\n" "${entry%%:*}" "${entry#*:}"
  done
}

open_pane() {
  local name="${1:-}"
  [[ -n "$name" ]] || { usage; return 2; }
  local url
  url="$(pane_url "$name")" || { print -u2 -- "unknown pane: $name"; panes; return 2; }
  print -r -- "$url"
  open "$url"
}

guide() {
  cat <<'GUIDE'
macOS privacy grants are not normal Unix permissions.

What GAF can do safely:
- identify likely responsible apps and binaries;
- probe protected folders from shell and Python;
- open the relevant Privacy & Security panes;
- install stable managed config so agents use the same launch surfaces;
- document which app should be granted access.

What GAF should not do on a normal machine:
- write rows directly into TCC.db;
- run broad `tccutil reset` without explicit human approval;
- recursively chmod/chown protected folders as a privacy workaround;
- assume every CLI binary needs Full Disk Access.

Best practice:
1. Grant Full Disk Access to the app that launches agents: usually Ghostty and Codex.app.
2. Add CLI binaries only if the macOS prompt names the binary directly, such as Python.
3. For UI automation, grant Accessibility to the controlling app, not every CLI tool.
4. For microphone/camera, grant only the app that records, such as Granola.
5. Restart the affected app after granting access.
GUIDE
}

case "${1:-status}" in
  status) status ;;
  targets) targets ;;
  panes) panes ;;
  open) shift; open_pane "${1:-}" ;;
  guide) guide ;;
  -h|--help|help) usage ;;
  *) print -u2 -- "unknown subcommand: $1"; usage; exit 2 ;;
esac
