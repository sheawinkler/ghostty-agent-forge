#!/usr/bin/env python3
"""Prove that the public loader does not vendor private Agent Prime policy."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_ROOT = Path("tests/fixtures/prime")
STRUCTURALLY_PRIVATE_PATHS = {
    Path("agent-prime-pack.json"),
    Path("policy/agent-prime.json"),
}


def tracked_files() -> list[Path]:
    output = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
    )
    return [Path(item.decode()) for item in output.split(b"\0") if item]


def private_policy_strings(pack_root: Path) -> set[str]:
    manifest = json.loads(
        (pack_root / "agent-prime-pack.json").read_text(encoding="utf-8")
    )
    policy = json.loads(
        (pack_root / manifest["policy_path"]).read_text(encoding="utf-8")
    )
    strings: set[str] = set()
    for key in ("principles", "always_on_rules", "hard_stops"):
        strings.update(
            item
            for item in policy.get(key, [])
            if isinstance(item, str) and len(item) >= 40
        )
    for capability in policy.get("sigma_policy", {}).get("capabilities", []):
        if isinstance(capability, dict):
            rule = capability.get("rule")
            if isinstance(rule, str) and len(rule) >= 40:
                strings.add(rule)
    return strings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--private-pack", type=Path)
    args = parser.parse_args()
    failures: list[str] = []
    public_text: dict[Path, str] = {}

    for relative in tracked_files():
        if relative.is_relative_to(FIXTURE_ROOT):
            continue
        if relative in STRUCTURALLY_PRIVATE_PATHS:
            failures.append(f"private pack path is vendored publicly: {relative}")
        if (
            relative.name.startswith("agent_prime_analysis")
            or "generated/agent_prime" in relative.as_posix()
        ):
            failures.append(
                f"private generated analysis is vendored publicly: {relative}"
            )
        path = ROOT / relative
        try:
            public_text[relative] = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue

    if args.private_pack:
        pack_root = args.private_pack.expanduser().resolve()
        for private_string in private_policy_strings(pack_root):
            for relative, text in public_text.items():
                if private_string in text:
                    failures.append(
                        f"private policy rule leaked verbatim into {relative}"
                    )

    if failures:
        raise AssertionError(
            "public/private boundary failed:\n  - " + "\n  - ".join(failures)
        )
    print("public_private_boundary_ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
