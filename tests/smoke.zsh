#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ghostty-agent-forge-test.XXXXXX")"
trap "rm -rf -- '$TEST_ROOT'" EXIT INT TERM

export HOME="$TEST_ROOT/home"
export GAF_HOME="$TEST_ROOT/gaf"
export GAF_STATE_DIR="$TEST_ROOT/state"
export GAF_BEHAVIOR_HOME="$TEST_ROOT/packs"
export GAF_BEHAVIOR_SKIP_LOGIN_CHECK=1
export GAF_CODEX_ACCOUNTS_FILE="$TEST_ROOT/codex-accounts.tsv"
mkdir -p "$HOME/.codex"
print -r -- "unmanaged-user-rule" > "$HOME/.codex/AGENTS.md"

GAF="$ROOT/bin/gaf"
FIXTURE="$ROOT/tests/fixtures/prime"
PREVIOUS_FIXTURE="$TEST_ROOT/prime-previous"
COLLISION_FIXTURE="$TEST_ROOT/prime-collision"
INCOMPATIBLE_FIXTURE="$TEST_ROOT/prime-incompatible"

zsh -n "$ROOT"/scripts/*.zsh "$ROOT"/zsh/*.zsh "$GAF"
python3 -m py_compile "$ROOT"/scripts/*.py "$FIXTURE/scripts/render-agent-prime.py"
python3 -m json.tool "$ROOT/config/agent-runtime.json" >/dev/null
python3 "$ROOT/tests/public_private_boundary.py"
[[ "$(<"$ROOT/VERSION")" == "$($GAF version)" ]]

HEADLESS_BIN="$TEST_ROOT/headless-bin"
HEADLESS_MARKER="$TEST_ROOT/direnv-invoked"
mkdir -p "$HEADLESS_BIN"
cat > "$HEADLESS_BIN/direnv" <<'EOF'
#!/bin/sh
: > "$HEADLESS_MARKER"
printf '%s\n' 'true'
EOF
chmod +x "$HEADLESS_BIN/direnv"
HEADLESS_MARKER="$HEADLESS_MARKER" PATH="$HEADLESS_BIN:$PATH" ROOT="$ROOT" zsh -fc '
  set -u
  source "$ROOT/zsh/tools.zsh"
  unset SPACESHIP_PROMPT_ASYNC
  source "$ROOT/zsh/prompt-spaceship.zsh"
  [[ -z "${SPACESHIP_PROMPT_ASYNC+x}" ]]
'
[[ ! -e "$HEADLESS_MARKER" ]]

"$GAF" rules >/dev/null
"$GAF" doctor >"$TEST_ROOT/doctor.out"
grep -q "Ghostty Agent Forge doctor" "$TEST_ROOT/doctor.out"
grep -q "brew" "$TEST_ROOT/doctor.out"

"$GAF" resources tools >"$TEST_ROOT/resource-tools.out"
grep -q "btop" "$TEST_ROOT/resource-tools.out"
"$GAF" resources snapshot >"$TEST_ROOT/resource-snapshot.json"
python3 -m json.tool "$TEST_ROOT/resource-snapshot.json" >/dev/null
"$GAF" resources status >"$TEST_ROOT/resource-status.out"
grep -q "Ghostty Agent Forge resource status" "$TEST_ROOT/resource-status.out"

cp -R "$FIXTURE" "$PREVIOUS_FIXTURE"
python3 - "$PREVIOUS_FIXTURE" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
for relative in ("agent-prime-pack.json", "policy/agent-prime.json"):
    path = root / relative
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["version"] = "9.9.8"
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
"$GAF" behavior install --prime --source "$PREVIOUS_FIXTURE" --yes >/dev/null
"$GAF" behavior install --prime --source "$FIXTURE" --yes >"$TEST_ROOT/behavior-install.out"
grep -q "unmanaged-user-rule" "$HOME/.codex/AGENTS.md"
grep -q 'Version: `9.9.9`' "$HOME/.codex/AGENTS.md"

"$GAF" behavior status >"$TEST_ROOT/behavior-status.out"
grep -q "Agent behavior packs" "$TEST_ROOT/behavior-status.out"
"$GAF" behavior list >"$TEST_ROOT/behavior-list.out"
grep -q "9.9.8" "$TEST_ROOT/behavior-list.out"
grep -q "9.9.9" "$TEST_ROOT/behavior-list.out"
"$GAF" behavior doctor >"$TEST_ROOT/behavior-doctor.out"
grep -q "Behavior render dry run" "$TEST_ROOT/behavior-doctor.out"
grep -q "Harness policy coverage: ok" "$TEST_ROOT/behavior-doctor.out"

"$GAF" harnesses status --json >"$TEST_ROOT/harnesses.json"
python3 - "$TEST_ROOT/harnesses.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["pack"]["version"] == "9.9.9"
assert len(payload["harnesses"]) >= 11
assert all(item["policy_state"] == "current" for item in payload["harnesses"])
PY

"$GAF" behavior rollback 9.9.8 --dry-run >"$TEST_ROOT/rollback-dry-run.out"
grep -q "9.9.9 -> 9.9.8" "$TEST_ROOT/rollback-dry-run.out"
"$GAF" behavior rollback 9.9.8 --yes >/dev/null
grep -q 'Version: `9.9.8`' "$HOME/.codex/AGENTS.md"
"$GAF" behavior install --prime --source "$FIXTURE" --yes >/dev/null

cp -R "$FIXTURE" "$COLLISION_FIXTURE"
python3 - "$COLLISION_FIXTURE/policy/agent-prime.json" <<'PY'
import json, sys
path = sys.argv[1]
payload = json.load(open(path, encoding="utf-8"))
payload["collision"] = True
open(path, "w", encoding="utf-8").write(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY
if "$GAF" behavior install --prime --source "$COLLISION_FIXTURE" --yes --no-render >"$TEST_ROOT/collision.out" 2>&1; then
  print -u2 -- "same-version behavior collision unexpectedly succeeded"
  exit 1
fi
grep -q "refusing mutable version collision" "$TEST_ROOT/collision.out"

cp -R "$FIXTURE" "$INCOMPATIBLE_FIXTURE"
python3 - "$INCOMPATIBLE_FIXTURE/agent-prime-pack.json" <<'PY'
import json, sys
path = sys.argv[1]
payload = json.load(open(path, encoding="utf-8"))
payload["requires"]["ghostty_agent_forge_min"] = "99.0.0"
open(path, "w", encoding="utf-8").write(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY
if "$GAF" behavior install --prime --source "$INCOMPATIBLE_FIXTURE" --dry-run >"$TEST_ROOT/incompatible.out" 2>&1; then
  print -u2 -- "incompatible behavior pack unexpectedly passed validation"
  exit 1
fi
grep -q "requires Ghostty Agent Forge >= 99.0.0" "$TEST_ROOT/incompatible.out"

python3 - "$TEST_ROOT/unsafe.tar.gz" <<'PY'
import io, sys, tarfile
archive = sys.argv[1]
with tarfile.open(archive, "w:gz") as bundle:
    member = tarfile.TarInfo("../escape")
    payload = b"escape\n"
    member.size = len(payload)
    bundle.addfile(member, io.BytesIO(payload))
PY
if python3 "$ROOT/scripts/behavior-pack.py" extract \
  --archive "$TEST_ROOT/unsafe.tar.gz" \
  --dest "$TEST_ROOT/unsafe-output" >"$TEST_ROOT/unsafe.out" 2>&1; then
  print -u2 -- "unsafe behavior archive unexpectedly extracted"
  exit 1
fi
grep -q "unsafe archive member path" "$TEST_ROOT/unsafe.out"

GAF_CODEX_BIN=/usr/bin/true "$GAF" codex add pro "$TEST_ROOT/codex-pro" --yes >/dev/null
grep -q 'Version: `9.9.9`' "$TEST_ROOT/codex-pro/AGENTS.md"
GAF_CODEX_BIN=/usr/bin/true "$GAF" codex list >"$TEST_ROOT/codex-list.out"
grep -q "pro" "$TEST_ROOT/codex-list.out"
GAF_CODEX_BIN=/usr/bin/true "$GAF" codex status --all >/dev/null
GAF_CODEX_BIN=/usr/bin/true "$GAF" codex pro --version
"$GAF" harnesses doctor --json >"$TEST_ROOT/harnesses-with-profile.json"
python3 - "$TEST_ROOT/harnesses-with-profile.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
profiles = {item["id"]: item for item in payload["harnesses"]}
assert profiles["codex-profile-pro"]["policy_state"] == "current"
PY

"$GAF" self status >"$TEST_ROOT/self-status.out"
grep -q "version  0.2.1" "$TEST_ROOT/self-status.out"
"$GAF" self update --dry-run >"$TEST_ROOT/self-update.out"
grep -q "would clone" "$TEST_ROOT/self-update.out"

mkdir -p "$TEST_ROOT/claude"
cat > "$TEST_ROOT/claude/settings.json" <<'JSON'
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
"$GAF" claude permissions install --yes --claude-dir "$TEST_ROOT/claude" >"$TEST_ROOT/claude-install.out"
grep -q "Installed Claude Code Bash approval hook" "$TEST_ROOT/claude-install.out"
"$GAF" claude permissions status --claude-dir "$TEST_ROOT/claude" >"$TEST_ROOT/claude-status.out"
grep -q "Claude Code permissions status" "$TEST_ROOT/claude-status.out"
"$GAF" claude permissions doctor --claude-dir "$TEST_ROOT/claude" >"$TEST_ROOT/claude-doctor.out"
grep -q "pretool_nested_sudo" "$TEST_ROOT/claude-doctor.out"
jq -e '
  (.permissions.defaultMode == "acceptEdits")
  and ((.permissions.allow // []) | index("Bash"))
  and (((.permissions.ask // []) | map(select(type == "string" and (. == "Bash" or startswith("Bash(")))) | length) == 0)
  and (((.permissions.deny // []) | map(select(type == "string" and (. == "Bash" or startswith("Bash(")))) | length) == 0)
  and (((.hooks.PreToolUse // []) | map(select(.matcher == "Bash")) | length) == 1)
  and (((.hooks.PermissionRequest // []) | map(select(.matcher == "Bash")) | length) == 1)
' "$TEST_ROOT/claude/settings.json" >/dev/null

"$GAF" tcc status >"$TEST_ROOT/tcc-status.out"
grep -q "Ghostty Agent Forge macOS TCC doctor" "$TEST_ROOT/tcc-status.out"
"$GAF" tcc targets >"$TEST_ROOT/tcc-targets.out"
grep -q "Permission targets" "$TEST_ROOT/tcc-targets.out"
"$GAF" tcc panes >"$TEST_ROOT/tcc-panes.out"
grep -q "full-disk-access" "$TEST_ROOT/tcc-panes.out"
! grep -Eq "microphone|camera" "$TEST_ROOT/tcc-panes.out"
"$GAF" tcc guide >"$TEST_ROOT/tcc-guide.out"
grep -q "macOS privacy grants are not normal Unix permissions" "$TEST_ROOT/tcc-guide.out"

"$GAF" resources install-agent --dry-run >"$TEST_ROOT/resource-agent.out"
grep -q "resources snapshot --append" "$TEST_ROOT/resource-agent.out"
"$GAF" macos status >"$TEST_ROOT/macos-status.out"
grep -q "macOS performance restore status" "$TEST_ROOT/macos-status.out"
"$GAF" macos restore >"$TEST_ROOT/macos-restore.out"
grep -q "mode: dry-run" "$TEST_ROOT/macos-restore.out"
"$GAF" macos install-agent >"$TEST_ROOT/macos-agent.out"
grep -q "run .* restore --yes" "$TEST_ROOT/macos-agent.out"

"$GAF" blackbox -- zsh -fc true >"$TEST_ROOT/blackbox.out"
grep -q '"exit_code": 0' "$TEST_ROOT/blackbox.out"
"$GAF" profile export "$TEST_ROOT/profile.json" >/dev/null
python3 -m json.tool "$TEST_ROOT/profile.json" >/dev/null

"$ROOT/scripts/bootstrap-ghostty-agent-forge.zsh" \
  --dry-run \
  --no-ghostty \
  --no-oh-my-zsh \
  --no-contextlattice-prompt >"$TEST_ROOT/bootstrap-dry-run.out"
grep -q "ghostty-agent-forge" "$TEST_ROOT/bootstrap-dry-run.out"

print "smoke_ok"
