#!/bin/zsh
set -euo pipefail

echo "Ghostty Agent Forge macOS TCC doctor"
echo

check_path() {
  local label="$1"
  local path="$2"
  if /bin/ls "$path" >/dev/null 2>&1; then
    printf "ok     %s: %s\n" "$label" "$path"
  else
    printf "blocked %s: %s\n" "$label" "$path"
  fi
}

check_path "home" "$HOME"
check_path "documents" "$HOME/Documents"
check_path "downloads" "$HOME/Downloads"

if [[ -d /Volumes ]]; then
  for volume in /Volumes/*(N); do
    [[ "$volume" == "/Volumes/Macintosh HD" ]] && continue
    check_path "volume" "$volume"
  done
fi

echo
echo "If Documents or external volumes are blocked, diagnose macOS Privacy & Security first."
echo "Do not fix this with recursive chmod unless Unix mode bits are proven to be the issue."

