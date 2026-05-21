#!/bin/zsh
set -euo pipefail

BASE_URL="${CONTEXTLATTICE_ORCHESTRATOR_URL:-http://127.0.0.1:8075}"
PROJECT="${CONTEXTLATTICE_PROJECT:-contextlattice}"
AGENT_ID="${CONTEXTLATTICE_AGENT_ID:-ghostty_agent_forge}"

curl -fsS --max-time 5 "$BASE_URL/health" >/dev/null

QUERY="ghostty agent forge terminal visibility preflight"
BASE_URL="$BASE_URL" PROJECT="$PROJECT" AGENT_ID="$AGENT_ID" QUERY="$QUERY" python3 - <<'PY'
import json
import os
import urllib.request

payload = {
    "query": os.environ["QUERY"],
    "project": os.environ["PROJECT"],
    "limit": 5,
    "include_grounding": True,
    "include_retrieval_debug": True,
    "agent_id": os.environ["AGENT_ID"],
    "retrieval_mode": "fast",
}
req = urllib.request.Request(
    f"{os.environ['BASE_URL']}/memory/search",
    data=json.dumps(payload).encode(),
    headers={"content-type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=20) as resp:
    data = json.load(resp)
print(json.dumps({
    "ok": data.get("ok", True),
    "results": len(data.get("results") or []),
    "degraded": data.get("degraded"),
    "warnings": data.get("warnings") or [],
}, indent=2))
PY

