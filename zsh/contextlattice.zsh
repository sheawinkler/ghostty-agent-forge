# Optional ContextLattice hooks for local agent visibility.

export CONTEXTLATTICE_ORCHESTRATOR_URL="${CONTEXTLATTICE_ORCHESTRATOR_URL:-http://127.0.0.1:8075}"
export MEMMCP_ORCHESTRATOR_URL="${MEMMCP_ORCHESTRATOR_URL:-$CONTEXTLATTICE_ORCHESTRATOR_URL}"
export CONTEXTLATTICE_PROJECT="${CONTEXTLATTICE_PROJECT:-contextlattice}"
export MEMMCP_PROJECT="${MEMMCP_PROJECT:-$CONTEXTLATTICE_PROJECT}"
export CONTEXTLATTICE_AGENT_BASE="${CONTEXTLATTICE_AGENT_BASE:-local_agent}"
export MEMMCP_AGENT_BASE="${MEMMCP_AGENT_BASE:-$CONTEXTLATTICE_AGENT_BASE}"

if [[ -z "${CODEX_AGENT_SESSION_ID:-}" ]]; then
  CODEX_AGENT_SESSION_ID="s$(date +%Y%m%d%H%M%S)-$$"
  export CODEX_AGENT_SESSION_ID
fi

export CONTEXTLATTICE_AGENT_ID="${CONTEXTLATTICE_AGENT_ID:-${CONTEXTLATTICE_AGENT_BASE}_${CODEX_AGENT_SESSION_ID}}"
export MEMMCP_AGENT_ID="${MEMMCP_AGENT_ID:-${MEMMCP_AGENT_BASE}_${CODEX_AGENT_SESSION_ID}}"

cl-health() {
  curl -fsS --max-time 5 "${CONTEXTLATTICE_ORCHESTRATOR_URL}/health"
}

cl-search() {
  local query="${1:-}"
  local project="${2:-$CONTEXTLATTICE_PROJECT}"
  if [[ -z "$query" ]]; then
    print -u2 -- "usage: cl-search <query> [project]"
    return 2
  fi
  QUERY="$query" PROJECT="$project" python3 - <<'PY'
import json
import os
import urllib.request

base = os.environ.get("CONTEXTLATTICE_ORCHESTRATOR_URL", "http://127.0.0.1:8075")
payload = {
    "query": os.environ["QUERY"],
    "project": os.environ.get("PROJECT") or "contextlattice",
    "limit": 8,
    "include_grounding": True,
    "include_retrieval_debug": True,
    "agent_id": os.environ.get("CONTEXTLATTICE_AGENT_ID", "local_agent"),
    "retrieval_mode": "fast",
}
req = urllib.request.Request(
    f"{base}/memory/search",
    data=json.dumps(payload).encode(),
    headers={"content-type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=20) as resp:
    print(json.dumps(json.load(resp), indent=2))
PY
}

cl-preflight() {
  cl-health >/dev/null && cl-search "terminal visibility agent shell preflight" "$CONTEXTLATTICE_PROJECT" >/dev/null
}

memwrite() {
  local file="${1:-}"
  shift || true
  if [[ -z "$file" ]]; then
    print -u2 -- "usage: memwrite <path> [content...]"
    return 2
  fi
  local content
  if [[ -t 0 ]]; then
    content="$*"
  else
    content="$(cat)"
  fi
  FILE="$file" CONTENT="$content" python3 - <<'PY'
import json
import os
import urllib.request

base = os.environ.get("CONTEXTLATTICE_ORCHESTRATOR_URL", "http://127.0.0.1:8075")
payload = {
    "projectName": os.environ.get("CONTEXTLATTICE_PROJECT", "contextlattice"),
    "fileName": os.environ["FILE"],
    "content": os.environ.get("CONTENT", ""),
}
req = urllib.request.Request(
    f"{base}/memory/write",
    data=json.dumps(payload).encode(),
    headers={"content-type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=20) as resp:
    print(resp.read().decode("utf-8", errors="replace"))
PY
}

