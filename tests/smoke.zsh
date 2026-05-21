#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"

zsh -n "$ROOT"/scripts/*.zsh "$ROOT"/zsh/*.zsh "$ROOT"/bin/gaf

"$ROOT/bin/gaf" version >/dev/null
"$ROOT/bin/gaf" rules >/dev/null
"$ROOT/bin/gaf" doctor >/tmp/ghostty-agent-forge-doctor.out
grep -q "Ghostty Agent Forge doctor" /tmp/ghostty-agent-forge-doctor.out
grep -q "brew" /tmp/ghostty-agent-forge-doctor.out
GAF_STATE_DIR=/tmp/ghostty-agent-forge-state "$ROOT/bin/gaf" blackbox -- zsh -fc true >/tmp/ghostty-agent-forge-blackbox.out
grep -q '"exit_code": 0' /tmp/ghostty-agent-forge-blackbox.out
"$ROOT/bin/gaf" profile export /tmp/ghostty-agent-forge-profile.json >/dev/null
python3 -m json.tool "$ROOT/config/agent-runtime.json" >/dev/null
python3 -m json.tool /tmp/ghostty-agent-forge-profile.json >/dev/null
rm -f /tmp/ghostty-agent-forge-profile.json
rm -f /tmp/ghostty-agent-forge-doctor.out
rm -f /tmp/ghostty-agent-forge-blackbox.out
rm -rf /tmp/ghostty-agent-forge-state

"$ROOT/scripts/bootstrap-ghostty-agent-forge.zsh" --dry-run --no-ghostty --no-oh-my-zsh --no-contextlattice-prompt >/tmp/ghostty-agent-forge-dryrun.out
grep -q "ghostty-agent-forge" /tmp/ghostty-agent-forge-dryrun.out
rm -f /tmp/ghostty-agent-forge-dryrun.out

print "smoke_ok"
