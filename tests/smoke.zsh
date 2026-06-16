#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"

zsh -n "$ROOT"/scripts/*.zsh "$ROOT"/zsh/*.zsh "$ROOT"/bin/gaf

"$ROOT/bin/gaf" version >/dev/null
"$ROOT/bin/gaf" rules >/dev/null
"$ROOT/bin/gaf" doctor >/tmp/ghostty-agent-forge-doctor.out
grep -q "Ghostty Agent Forge doctor" /tmp/ghostty-agent-forge-doctor.out
grep -q "brew" /tmp/ghostty-agent-forge-doctor.out
"$ROOT/bin/gaf" resources tools >/tmp/ghostty-agent-forge-resource-tools.out
grep -q "btop" /tmp/ghostty-agent-forge-resource-tools.out
"$ROOT/bin/gaf" resources snapshot >/tmp/ghostty-agent-forge-resource-snapshot.json
python3 -m json.tool /tmp/ghostty-agent-forge-resource-snapshot.json >/dev/null
"$ROOT/bin/gaf" resources status >/tmp/ghostty-agent-forge-resource-status.out
grep -q "Ghostty Agent Forge resource status" /tmp/ghostty-agent-forge-resource-status.out
"$ROOT/bin/gaf" behavior status >/tmp/ghostty-agent-forge-behavior-status.out
grep -q "Agent behavior packs" /tmp/ghostty-agent-forge-behavior-status.out
"$ROOT/bin/gaf" behavior doctor >/tmp/ghostty-agent-forge-behavior-doctor.out
grep -q "Behavior render dry run" /tmp/ghostty-agent-forge-behavior-doctor.out
rm -rf /tmp/ghostty-agent-forge-claude
mkdir -p /tmp/ghostty-agent-forge-claude
cat > /tmp/ghostty-agent-forge-claude/settings.json <<'JSON'
{
  "permissions": {
    "allow": ["Read"],
    "ask": ["Bash(grep:*)", "WebFetch"],
    "deny": ["Bash(rm:*)", "Write"]
  },
  "hooks": {
    "PreToolUse": [{"matcher": "Read", "hooks": []}, {"matcher": "Bash", "hooks": []}],
    "PermissionRequest": [{"matcher": "Bash", "hooks": []}]
  }
}
JSON
"$ROOT/bin/gaf" claude permissions install --yes --claude-dir /tmp/ghostty-agent-forge-claude >/tmp/ghostty-agent-forge-claude-install.out
grep -q "Installed Claude Code Bash approval hook" /tmp/ghostty-agent-forge-claude-install.out
"$ROOT/bin/gaf" claude permissions status --claude-dir /tmp/ghostty-agent-forge-claude >/tmp/ghostty-agent-forge-claude-status.out
grep -q "Claude Code permissions status" /tmp/ghostty-agent-forge-claude-status.out
"$ROOT/bin/gaf" claude permissions doctor --claude-dir /tmp/ghostty-agent-forge-claude >/tmp/ghostty-agent-forge-claude-doctor.out
grep -q "pretool_nested_sudo" /tmp/ghostty-agent-forge-claude-doctor.out
jq -e '
  (.permissions.defaultMode == "acceptEdits")
  and ((.permissions.allow // []) | index("Bash"))
  and (((.permissions.ask // []) | map(select(type == "string" and (. == "Bash" or startswith("Bash(")))) | length) == 0)
  and (((.permissions.deny // []) | map(select(type == "string" and (. == "Bash" or startswith("Bash(")))) | length) == 0)
  and (((.hooks.PreToolUse // []) | map(select(.matcher == "Bash")) | length) == 1)
  and (((.hooks.PermissionRequest // []) | map(select(.matcher == "Bash")) | length) == 1)
' /tmp/ghostty-agent-forge-claude/settings.json >/dev/null
"$ROOT/bin/gaf" tcc status >/tmp/ghostty-agent-forge-tcc-status.out
grep -q "Ghostty Agent Forge macOS TCC doctor" /tmp/ghostty-agent-forge-tcc-status.out
"$ROOT/bin/gaf" tcc targets >/tmp/ghostty-agent-forge-tcc-targets.out
grep -q "Permission targets" /tmp/ghostty-agent-forge-tcc-targets.out
"$ROOT/bin/gaf" tcc panes >/tmp/ghostty-agent-forge-tcc-panes.out
grep -q "full-disk-access" /tmp/ghostty-agent-forge-tcc-panes.out
! grep -Eq "microphone|camera" /tmp/ghostty-agent-forge-tcc-panes.out
"$ROOT/bin/gaf" tcc guide >/tmp/ghostty-agent-forge-tcc-guide.out
grep -q "macOS privacy grants are not normal Unix permissions" /tmp/ghostty-agent-forge-tcc-guide.out
"$ROOT/bin/gaf" resources install-agent --dry-run >/tmp/ghostty-agent-forge-resource-agent.out
grep -q "resources snapshot --append" /tmp/ghostty-agent-forge-resource-agent.out
"$ROOT/bin/gaf" macos status >/tmp/ghostty-agent-forge-macos-status.out
grep -q "macOS performance restore status" /tmp/ghostty-agent-forge-macos-status.out
"$ROOT/bin/gaf" macos restore >/tmp/ghostty-agent-forge-macos-restore.out
grep -q "mode: dry-run" /tmp/ghostty-agent-forge-macos-restore.out
"$ROOT/bin/gaf" macos install-agent >/tmp/ghostty-agent-forge-macos-agent.out
grep -q "run .* restore --yes" /tmp/ghostty-agent-forge-macos-agent.out
GAF_STATE_DIR=/tmp/ghostty-agent-forge-state "$ROOT/bin/gaf" blackbox -- zsh -fc true >/tmp/ghostty-agent-forge-blackbox.out
grep -q '"exit_code": 0' /tmp/ghostty-agent-forge-blackbox.out
"$ROOT/bin/gaf" profile export /tmp/ghostty-agent-forge-profile.json >/dev/null
python3 -m json.tool "$ROOT/config/agent-runtime.json" >/dev/null
python3 -m json.tool /tmp/ghostty-agent-forge-profile.json >/dev/null
rm -f /tmp/ghostty-agent-forge-profile.json
rm -f /tmp/ghostty-agent-forge-doctor.out
rm -f /tmp/ghostty-agent-forge-resource-tools.out
rm -f /tmp/ghostty-agent-forge-resource-snapshot.json
rm -f /tmp/ghostty-agent-forge-resource-status.out
rm -f /tmp/ghostty-agent-forge-behavior-status.out
rm -f /tmp/ghostty-agent-forge-behavior-doctor.out
rm -f /tmp/ghostty-agent-forge-claude-install.out
rm -f /tmp/ghostty-agent-forge-claude-status.out
rm -f /tmp/ghostty-agent-forge-claude-doctor.out
rm -rf /tmp/ghostty-agent-forge-claude
rm -f /tmp/ghostty-agent-forge-tcc-status.out
rm -f /tmp/ghostty-agent-forge-tcc-targets.out
rm -f /tmp/ghostty-agent-forge-tcc-panes.out
rm -f /tmp/ghostty-agent-forge-tcc-guide.out
rm -f /tmp/ghostty-agent-forge-resource-agent.out
rm -f /tmp/ghostty-agent-forge-macos-status.out
rm -f /tmp/ghostty-agent-forge-macos-restore.out
rm -f /tmp/ghostty-agent-forge-macos-agent.out
rm -f /tmp/ghostty-agent-forge-blackbox.out
rm -rf /tmp/ghostty-agent-forge-state

"$ROOT/scripts/bootstrap-ghostty-agent-forge.zsh" --dry-run --no-ghostty --no-oh-my-zsh --no-contextlattice-prompt >/tmp/ghostty-agent-forge-dryrun.out
grep -q "ghostty-agent-forge" /tmp/ghostty-agent-forge-dryrun.out
rm -f /tmp/ghostty-agent-forge-dryrun.out

print "smoke_ok"
