#!/usr/bin/env python3
"""Sanitized renderer used only for public GAF contract tests."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

START = "<!-- >>> contextlattice-agent-prime >>> -->"
END = "<!-- <<< contextlattice-agent-prime <<< -->"


def remove_managed(text: str) -> str:
    output = []
    skipping = False
    for line in text.splitlines():
        if line.strip() == START:
            skipping = True
            continue
        if line.strip() == END:
            skipping = False
            continue
        if not skipping:
            output.append(line)
    return "\n".join(output).rstrip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack-root", required=True)
    parser.add_argument("--home", required=True)
    parser.add_argument("--gaf-home", required=True)
    parser.add_argument("--output-root", default="")
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    pack_root = Path(args.pack_root).resolve()
    home = Path(args.home).resolve()
    gaf_home = Path(args.gaf_home).resolve()
    manifest = json.loads(
        (pack_root / "agent-prime-pack.json").read_text(encoding="utf-8")
    )
    version = manifest["version"]
    block = f"{START}\n# Agent Prime Test Fixture\n\nVersion: `{version}`\n{END}\n"
    targets = [
        ("codex", home / ".codex" / "AGENTS.md"),
        ("claude-code", home / ".claude" / "CLAUDE.md"),
        ("gemini-cli", home / ".gemini" / "GEMINI.md"),
        ("opencode", home / ".config" / "opencode" / "AGENTS.md"),
        ("hermes", home / ".hermes" / "SOUL.md"),
        ("hermes-agent-ultra", home / ".hermes-agent-ultra" / "SOUL.md"),
        ("omp", home / ".omp" / "agent" / "AGENTS.md"),
        ("droid", home / ".droid" / "AGENTS.md"),
        ("pi-coding-agent", home / ".pi-coding-agent" / "AGENTS.md"),
        ("mercury-agent", home / ".mercury" / "soul.md"),
        ("ghostty-agent-forge", gaf_home / "AGENTS.md"),
    ]
    registry = Path(
        os.environ.get("GAF_CODEX_ACCOUNTS_FILE", str(gaf_home / "codex-accounts.tsv"))
    )
    if registry.is_file():
        for raw_line in registry.read_text(encoding="utf-8").splitlines():
            if not raw_line or raw_line.startswith("#"):
                continue
            profile, profile_home = raw_line.split("\t", maxsplit=1)
            targets.append(
                (f"codex-profile-{profile}", Path(profile_home) / "AGENTS.md")
            )
    changed = []
    if args.install:
        for target_id, path in targets:
            old = path.read_text(encoding="utf-8") if path.exists() else ""
            unmanaged = remove_managed(old)
            new = f"{unmanaged}\n\n{block}" if unmanaged else block
            if new != old:
                changed.append(str(path))
                if not args.dry_run:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(new, encoding="utf-8")
    result = {
        "ok": True,
        "schema_id": "contextlattice_agent_prime_render.test_fixture.v1",
        "pack": {"name": manifest["name"], "version": version, "root": str(pack_root)},
        "install": args.install,
        "dry_run": args.dry_run,
        "changed": changed,
        "install_targets": [
            {
                "id": target_id,
                "label": target_id,
                "path": str(path),
                "surface": "managed_markdown",
                "autoload": "test fixture",
            }
            for target_id, path in targets
        ],
    }
    print(json.dumps(result, indent=2 if args.pretty else None, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
