#!/bin/zsh
set -euo pipefail

CLAUDE_DIR_DEFAULT="$HOME/.claude"

usage() {
  cat <<'USAGE'
usage: claude-permissions.zsh <status|install|doctor> [--claude-dir path] [--yes|--dry-run]

Subcommands:
  status       Inspect Claude Code Bash approval hook and settings.
  install      Install/update the Bash approval hook. Requires --yes unless --dry-run.
  doctor       Run status plus hook behavior simulations.

Behavior installed by this helper:
  non-sudo Bash/zsh/git/python/python3: auto-allowed
  executable sudo: approval prompt
USAGE
}

print_check() {
  local check_status="$1" label="$2" value="${3:-}"
  printf "%-8s %-30s %s\n" "$check_status" "$label" "$value"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

parse_common() {
  claude_dir="$CLAUDE_DIR_DEFAULT"
  yes=0
  dry_run=0
  while (( $# > 0 )); do
    case "$1" in
      --claude-dir)
        shift
        claude_dir="${1:-}"
        [[ -n "$claude_dir" ]] || { print -u2 -- "missing path for --claude-dir"; return 2; }
        ;;
      --yes|-y) yes=1 ;;
      --dry-run) dry_run=1 ;;
      -h|--help|help) usage; return 0 ;;
      *) print -u2 -- "unknown arg: $1"; return 2 ;;
    esac
    shift
  done
  hook_dir="$claude_dir/hooks"
  hook="$hook_dir/bash-approval.py"
  settings="$claude_dir/settings.json"
}

write_hook_file() {
  local target="$1"
  cat > "$target" <<'PY'
#!/usr/bin/env python3
import json
import os
import re
import shlex
import sys

SHELLS = {"sh", "bash", "zsh"}
WRAPPERS = {"command", "builtin", "exec", "noglob"}
PYTHON = re.compile(r"python(?:3(?:\.\d+)?)?$")


def send(obj):
    print(json.dumps(obj, separators=(",", ":")))
    sys.exit(0)


def pretool(decision, reason):
    send({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    })


def permission_allow():
    send({
        "hookSpecificOutput": {
            "hookEventName": "PermissionRequest",
            "decision": {"behavior": "allow"},
        }
    })


def is_assignment(token):
    return re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", token) is not None


def basename(token):
    return os.path.basename(token)


def split_commands(command):
    chunks, buf = [], []
    quote = None
    escaped = False
    comment = False

    def flush():
        chunk = "".join(buf).strip()
        if chunk:
            chunks.append(chunk)
        buf.clear()

    i = 0
    while i < len(command):
        char = command[i]
        if comment:
            if char == "\n":
                comment = False
                flush()
            i += 1
            continue
        if escaped:
            buf.append("\\" + char)
            escaped = False
            i += 1
            continue
        if char == "\\" and quote != "'":
            escaped = True
            i += 1
            continue
        if quote:
            buf.append(char)
            if char == quote:
                quote = None
            i += 1
            continue
        if char in ("'", '"'):
            quote = char
            buf.append(char)
            i += 1
            continue
        if char == "#" and (not buf or buf[-1].isspace()):
            comment = True
            i += 1
            continue
        if char in "\n;|()":
            flush()
            i += 1
            continue
        if char == "&":
            flush()
            i += 2 if i + 1 < len(command) and command[i + 1] == "&" else 1
            continue
        buf.append(char)
        i += 1
    flush()
    return chunks


def effective_argv(argv):
    while argv:
        name = basename(argv[0])
        if is_assignment(argv[0]):
            argv = argv[1:]
            continue
        if name == "env":
            argv = argv[1:]
            while argv and (argv[0] == "--" or argv[0].startswith("-") or is_assignment(argv[0])):
                if argv[0] == "--":
                    argv = argv[1:]
                    break
                argv = argv[1:]
            continue
        if name in WRAPPERS:
            argv = argv[1:]
            continue
        if name == "time":
            argv = argv[1:]
            while argv and argv[0].startswith("-"):
                argv = argv[1:]
            continue
        return argv
    return []


def shell_c_payload(argv):
    for i, arg in enumerate(argv[1:], start=1):
        if arg == "-c" or (arg.startswith("-") and "c" in arg):
            return argv[i + 1] if i + 1 < len(argv) else ""
    return None


def has_executable_sudo(command, depth=0):
    if depth > 3:
        return False
    for chunk in split_commands(command):
        try:
            argv = effective_argv(shlex.split(chunk, posix=True))
        except ValueError:
            continue
        if not argv:
            continue
        name = basename(argv[0])
        # Explicit policy: all git and python/python3 commands are allowed.
        if name == "git" or PYTHON.fullmatch(name):
            continue
        if name == "sudo":
            return True
        # zsh/bash/sh are allowed, but sudo inside `zsh -c ...` still asks.
        if name in SHELLS:
            payload = shell_c_payload(argv)
            if payload is not None and has_executable_sudo(payload, depth + 1):
                return True
    return False


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if data.get("tool_name") != "Bash":
        sys.exit(0)
    event = data.get("hook_event_name") or "PreToolUse"
    command = (data.get("tool_input") or {}).get("command", "")
    sudo = has_executable_sudo(command)
    if event == "PreToolUse":
        if sudo:
            pretool("ask", "sudo requires explicit approval")
        pretool("allow", "allowed by Bash approval hook")
    if event == "PermissionRequest":
        if sudo:
            # Say nothing. Claude Code shows the normal approval prompt.
            sys.exit(0)
        permission_allow()


if __name__ == "__main__":
    main()
PY
}

settings_valid() {
  [[ -f "$settings" ]] && jq empty "$settings" >/dev/null 2>&1
}

settings_value() {
  local expr="$1"
  if settings_valid; then
    jq -r "$expr" "$settings" 2>/dev/null || true
  fi
}

status() {
  parse_common "$@" || return $?
  print "Claude Code permissions status"
  print
  have_cmd jq && print_check "ok" "jq" "$(command -v jq)" || print_check "missing" "jq" "required"
  have_cmd python3 && print_check "ok" "python3" "$(command -v python3)" || print_check "missing" "python3" "required"
  have_cmd claude && print_check "ok" "claude" "$(command -v claude)" || print_check "missing" "claude" "not required for install"
  print_check "info" "claude_dir" "$claude_dir"
  if [[ -f "$settings" ]]; then
    if settings_valid; then
      print_check "ok" "settings_json" "$settings"
    else
      print_check "fail" "settings_json" "invalid JSON: $settings"
    fi
  else
    print_check "missing" "settings_json" "$settings"
  fi
  if [[ -x "$hook" ]]; then
    if python3 -m py_compile "$hook" >/dev/null 2>&1; then
      print_check "ok" "hook" "$hook"
    else
      print_check "fail" "hook" "python compile failed: $hook"
    fi
  elif [[ -f "$hook" ]]; then
    print_check "warn" "hook" "not executable: $hook"
  else
    print_check "missing" "hook" "$hook"
  fi

  if settings_valid; then
    local allow_bash ask_bash deny_bash pretool permission default_mode
    default_mode="$(settings_value '.permissions.defaultMode // ""')"
    allow_bash="$(settings_value '(.permissions.allow // []) | any(. == "Bash")')"
    ask_bash="$(settings_value '(.permissions.ask // []) | map(select(type == "string" and (. == "Bash" or startswith("Bash(")))) | length')"
    deny_bash="$(settings_value '(.permissions.deny // []) | map(select(type == "string" and (. == "Bash" or startswith("Bash(")))) | length')"
    pretool="$(settings_value '(.hooks.PreToolUse // []) | map(select(.matcher == "Bash")) | length')"
    permission="$(settings_value '(.hooks.PermissionRequest // []) | map(select(.matcher == "Bash")) | length')"
    print_check "info" "default_mode" "$default_mode"
    [[ "$allow_bash" == "true" ]] && print_check "ok" "allow_Bash" "present" || print_check "missing" "allow_Bash" "permissions.allow lacks Bash"
    [[ "$ask_bash" == "0" ]] && print_check "ok" "ask_Bash_rules" "0" || print_check "warn" "ask_Bash_rules" "$ask_bash stale Bash rules"
    [[ "$deny_bash" == "0" ]] && print_check "ok" "deny_Bash_rules" "0" || print_check "warn" "deny_Bash_rules" "$deny_bash stale Bash rules"
    [[ "$pretool" == "1" ]] && print_check "ok" "PreToolUse_Bash_hook" "1" || print_check "warn" "PreToolUse_Bash_hook" "$pretool"
    [[ "$permission" == "1" ]] && print_check "ok" "PermissionRequest_hook" "1" || print_check "warn" "PermissionRequest_hook" "$permission"
  fi
}

install_permissions() {
  parse_common "$@" || return $?
  have_cmd jq || { print -u2 -- "ERROR: jq not found"; return 1; }
  have_cmd python3 || { print -u2 -- "ERROR: python3 not found"; return 1; }
  if (( ! yes && ! dry_run )); then
    print -r -- "This installs Claude Code Bash auto-approval hooks under: $claude_dir"
    print -r -- "Re-run with --yes to apply, or --dry-run to preview."
    return 2
  fi

  if (( dry_run )); then
    print -r -- "mode: dry-run"
    print -r -- "would write hook: $hook"
    print -r -- "would backup settings when present: $settings.bak.<timestamp>"
    print -r -- "would add permissions.allow Bash and remove Bash rules from ask/deny"
    print -r -- "would replace exact Bash matcher groups in PreToolUse and PermissionRequest"
    print -r -- "would preserve unrelated settings, hooks, and non-Bash permission rules"
    return 0
  fi

  local stamp tmp
  stamp="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$hook_dir"
  write_hook_file "$hook"
  chmod +x "$hook"
  python3 -m py_compile "$hook"

  if [[ -f "$settings" ]]; then
    cp -p "$settings" "$settings.bak.$stamp"
    if [[ ! -s "$settings" ]]; then
      printf '{}\n' > "$settings"
    elif ! jq empty "$settings" >/dev/null 2>&1; then
      print -u2 -- "ERROR: $settings is not valid JSON."
      print -u2 -- "Backup written to: $settings.bak.$stamp"
      return 1
    fi
  else
    mkdir -p "${settings:h}"
    printf '{}\n' > "$settings"
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/claude-settings.XXXXXX")"
  jq --arg hook "$hook" '
    def keep_non_bash_rule:
      if type == "string" then
        (. != "Bash" and (startswith("Bash(") | not))
      else
        true
      end;
    def bash_hook:
      {
        matcher: "Bash",
        hooks: [
          {
            type: "command",
            command: "python3",
            args: [$hook],
            timeout: 5
          }
        ]
      };
    .permissions = (.permissions // {})
    | .permissions.defaultMode = "acceptEdits"
    | .permissions.allow = ((.permissions.allow // []) | if index("Bash") then . else . + ["Bash"] end)
    | .permissions.ask = ((.permissions.ask // []) | map(select(keep_non_bash_rule)))
    | .permissions.deny = ((.permissions.deny // []) | map(select(keep_non_bash_rule)))
    | .hooks = (.hooks // {})
    | .hooks.PreToolUse = (((.hooks.PreToolUse // []) | map(select(.matcher != "Bash"))) + [bash_hook])
    | .hooks.PermissionRequest = (((.hooks.PermissionRequest // []) | map(select(.matcher != "Bash"))) + [bash_hook])
  ' "$settings" > "$tmp"
  mv "$tmp" "$settings"
  jq . "$settings" >/dev/null

  print "Installed Claude Code Bash approval hook."
  print "Hook:     $hook"
  print "Settings: $settings"
  [[ -f "$settings.bak.$stamp" ]] && print "Backup:   $settings.bak.$stamp"
  print
  print "Behavior:"
  print "  non-sudo Bash/zsh/git/python/python3: auto-allowed"
  print "  executable sudo: approval prompt"
  print
  print "Next: restart Claude Code, then run /hooks and /permissions to verify."
}

simulate_hook() {
  local event="$1" command="$2"
  printf '{"hook_event_name":"%s","tool_name":"Bash","tool_input":{"command":%s}}' "$event" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$command")" | "$hook"
}

doctor() {
  parse_common "$@" || return $?
  status --claude-dir "$claude_dir"
  print
  print "Hook simulations"
  [[ -x "$hook" ]] || { print_check "missing" "simulations" "hook not installed"; return 1; }
  local out
  out="$(simulate_hook PreToolUse 'echo ok')"
  print -r -- "$out" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null
  print_check "ok" "pretool_non_sudo" "allow"
  out="$(simulate_hook PreToolUse 'zsh -c "sudo whoami"')"
  print -r -- "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null
  print_check "ok" "pretool_nested_sudo" "ask"
  out="$(simulate_hook PermissionRequest 'git status')"
  print -r -- "$out" | jq -e '.hookSpecificOutput.decision.behavior == "allow"' >/dev/null
  print_check "ok" "permission_non_sudo" "allow"
  out="$(simulate_hook PermissionRequest 'sudo whoami')"
  [[ -z "$out" ]] && print_check "ok" "permission_sudo" "no auto-allow" || { print_check "fail" "permission_sudo" "$out"; return 1; }
}

sub="${1:-}"
shift || true
case "$sub" in
  status) status "$@" ;;
  install) install_permissions "$@" ;;
  doctor) doctor "$@" ;;
  -h|--help|help|"") usage ;;
  *) print -u2 -- "unknown subcommand: $sub"; usage; exit 2 ;;
esac
