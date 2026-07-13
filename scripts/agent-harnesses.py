#!/usr/bin/env python3
"""Report behavior-pack coverage across supported agent harnesses."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
from pathlib import Path
from typing import Any

MARKER = "contextlattice-agent-prime"
HARNESSES = (
    ("codex", ("codex",), ".codex/AGENTS.md"),
    ("claude-code", ("claude",), ".claude/CLAUDE.md"),
    ("gemini-cli", ("gemini",), ".gemini/GEMINI.md"),
    ("opencode", ("opencode",), ".config/opencode/AGENTS.md"),
    ("hermes", ("hermes",), ".hermes/SOUL.md"),
    (
        "hermes-agent-ultra",
        ("hermes-agent-ultra", "hermes"),
        ".hermes-agent-ultra/SOUL.md",
    ),
    ("omp", ("omp",), ".omp/agent/AGENTS.md"),
    ("droid", ("droid",), ".droid/AGENTS.md"),
    ("pi-coding-agent", ("pi", "pi-coding-agent"), ".pi-coding-agent/AGENTS.md"),
    ("mercury-agent", ("mercury",), ".mercury/soul.md"),
)


def codex_profile_definitions(
    home: Path, gaf_home: Path
) -> tuple[list[tuple[str, tuple[str, ...], str]], list[str]]:
    registry = Path(
        os.environ.get("GAF_CODEX_ACCOUNTS_FILE", str(gaf_home / "codex-accounts.tsv"))
    ).expanduser()
    if not registry.is_file():
        return [], []
    definitions: list[tuple[str, tuple[str, ...], str]] = []
    errors: list[str] = []
    for line_number, raw_line in enumerate(
        registry.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not raw_line or raw_line.startswith("#"):
            continue
        fields = raw_line.split("\t")
        if len(fields) != 2 or not re.fullmatch(r"[A-Za-z0-9._-]+", fields[0]):
            errors.append(f"invalid Codex profile row {line_number}")
            continue
        profile, raw_path = fields
        if raw_path == "~":
            profile_home = home
        elif raw_path.startswith("~/"):
            profile_home = home / raw_path[2:]
        else:
            profile_home = Path(raw_path)
        if not profile_home.is_absolute():
            errors.append(f"Codex profile home is not absolute on row {line_number}")
            continue
        if profile_home.resolve(strict=False) == (home / ".codex").resolve(
            strict=False
        ):
            continue
        definitions.append(
            (
                f"codex-profile-{profile}",
                ("codex",),
                str(profile_home / "AGENTS.md"),
            )
        )
    return definitions, errors


def current_pack() -> tuple[Path | None, str | None]:
    behavior_home = Path(
        os.environ.get(
            "GAF_BEHAVIOR_HOME", str(Path.home() / ".contextlattice" / "agent-packs")
        )
    ).expanduser()
    configured_link = Path(
        os.environ.get(
            "GAF_BEHAVIOR_LINK",
            str(Path.home() / ".config" / "ghostty-agent-forge" / "behavior"),
        )
    ).expanduser()
    candidates = (configured_link, behavior_home / "prime" / "current")
    for candidate in candidates:
        if not candidate.exists():
            continue
        root = candidate.resolve()
        manifest = root / "agent-prime-pack.json"
        try:
            payload = json.loads(manifest.read_text(encoding="utf-8"))
            return root, str(payload["version"])
        except (OSError, KeyError, json.JSONDecodeError, TypeError):
            return root, None
    return None, None


def binary_for(candidates: tuple[str, ...]) -> str | None:
    for candidate in candidates:
        resolved = shutil.which(candidate)
        if resolved:
            return str(Path(resolved).resolve())
    return None


def policy_state(path: Path, version: str | None) -> str:
    if not path.is_file():
        return "absent"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return "unreadable"
    if MARKER not in text:
        return "unmanaged"
    if version is None:
        return "managed"
    return "current" if f"Version: `{version}`" in text else "stale"


def collect() -> dict[str, Any]:
    pack_root, version = current_pack()
    home = Path.home()
    gaf_home = Path(
        os.environ.get("GAF_HOME", str(home / ".config" / "ghostty-agent-forge"))
    ).expanduser()
    definitions = list(HARNESSES)
    codex_profiles, configuration_errors = codex_profile_definitions(home, gaf_home)
    definitions.extend(codex_profiles)
    profiles_root = home / ".hermes" / "profiles"
    if profiles_root.is_dir():
        for soul_path in sorted(profiles_root.glob("*/SOUL.md")):
            definitions.append(
                (
                    f"hermes-profile-{soul_path.parent.name}",
                    ("hermes",),
                    soul_path.relative_to(home).as_posix(),
                )
            )
    harnesses = []
    for harness_id, commands, relative_policy in definitions:
        policy = home / relative_policy
        harnesses.append(
            {
                "id": harness_id,
                "binary": binary_for(commands),
                "command_candidates": list(commands),
                "policy_path": str(policy),
                "policy_state": policy_state(policy, version),
            }
        )
    harnesses.append(
        {
            "id": "ghostty-agent-forge",
            "binary": binary_for(("gaf",)),
            "command_candidates": ["gaf"],
            "policy_path": str(gaf_home / "AGENTS.md"),
            "policy_state": policy_state(gaf_home / "AGENTS.md", version),
        }
    )
    return {
        "ok": pack_root is not None
        and version is not None
        and not configuration_errors,
        "schema_id": "ghostty_agent_forge.harness_status.v1",
        "pack": {"root": str(pack_root) if pack_root else None, "version": version},
        "harnesses": harnesses,
        "configuration_errors": configuration_errors,
    }


def print_table(payload: dict[str, Any]) -> None:
    pack = payload["pack"]
    print("Agent harness matrix")
    print(f"Prime pack: {pack['version'] or 'not installed'}")
    if pack["root"]:
        print(f"Pack root:  {pack['root']}")
    print()
    print(f"{'HARNESS':<22} {'BINARY':<9} {'POLICY':<10} PATH")
    for harness in payload["harnesses"]:
        binary_state = "present" if harness["binary"] else "missing"
        print(
            f"{harness['id']:<22} {binary_state:<9} {harness['policy_state']:<10} "
            f"{harness['policy_path']}"
        )
    if payload["configuration_errors"]:
        print()
        print("Configuration errors: " + ", ".join(payload["configuration_errors"]))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command", choices=("status", "doctor"), nargs="?", default="status"
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    payload = collect()
    failures = [
        harness["id"]
        for harness in payload["harnesses"]
        if harness["policy_state"] != "current"
    ]
    if args.command == "doctor":
        payload["failures"] = failures
        payload["ok"] = (
            bool(payload["pack"]["version"])
            and not failures
            and not payload["configuration_errors"]
        )
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print_table(payload)
        if args.command == "doctor":
            print()
            if failures:
                print("Policy failures: " + ", ".join(failures))
            else:
                print("Harness policy coverage: ok")
    return 0 if payload["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
