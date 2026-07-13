#!/usr/bin/env python3
"""Validate and safely unpack Ghostty Agent Forge behavior packs."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import tarfile
from pathlib import Path, PurePosixPath
from typing import Any

PACK_NAME = "contextlattice-agent-prime"
MAX_UNPACKED_BYTES = 64 * 1024 * 1024
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
TREE_EXCLUDES = {
    ".DS_Store",
    ".git",
    "__pycache__",
    ".pytest_cache",
    "dist",
    "generated",
}


def fail(message: str) -> None:
    raise SystemExit(f"behavior-pack: {message}")


def read_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read valid JSON from {path}: {exc}")
    if not isinstance(value, dict):
        fail(f"expected a JSON object in {path}")
    return value


def parse_semver(value: str, label: str) -> tuple[int, int, int]:
    match = SEMVER.fullmatch(value)
    if not match:
        fail(f"{label} must be plain MAJOR.MINOR.PATCH semver, got {value!r}")
    return tuple(int(part) for part in match.groups())  # type: ignore[return-value]


def relative_pack_path(root: Path, value: Any, label: str) -> Path:
    if not isinstance(value, str) or not value:
        fail(f"{label} must be a non-empty relative path")
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        fail(f"{label} must stay inside the pack: {value!r}")
    resolved = (root / candidate).resolve()
    try:
        resolved.relative_to(root)
    except ValueError:
        fail(f"{label} escapes the pack: {value!r}")
    return resolved


def validate_pack(args: argparse.Namespace) -> None:
    root = Path(args.pack).expanduser().resolve()
    manifest_path = root / "agent-prime-pack.json"
    manifest = read_object(manifest_path)
    if manifest.get("name") != PACK_NAME:
        fail(f"manifest name must be {PACK_NAME!r}")
    version = str(manifest.get("version", ""))
    parse_semver(version, "pack version")
    if manifest.get("visibility") not in {"private", "public-paid"}:
        fail("pack visibility must be private or public-paid")
    if manifest.get("allowed_github_login") != args.allowed_login:
        fail("pack GitHub login gate does not match the forge gate")

    requires = manifest.get("requires")
    if not isinstance(requires, dict):
        fail("manifest requires must be an object")
    minimum = str(requires.get("ghostty_agent_forge_min", ""))
    if parse_semver(args.gaf_version, "GAF version") < parse_semver(
        minimum, "minimum GAF version"
    ):
        fail(
            f"pack {version} requires Ghostty Agent Forge >= {minimum}; current is {args.gaf_version}"
        )

    renderer = relative_pack_path(root, manifest.get("renderer"), "renderer")
    policy = relative_pack_path(root, manifest.get("policy_path"), "policy_path")
    if not renderer.is_file() or not os.access(renderer, os.X_OK):
        fail(f"renderer is missing or not executable: {renderer}")
    if not policy.is_file():
        fail(f"policy file is missing: {policy}")
    policy_payload = read_object(policy)
    if str(policy_payload.get("version", "")) != version:
        fail("policy version does not match pack version")

    print(
        json.dumps(
            {
                "ok": True,
                "name": PACK_NAME,
                "version": version,
                "gaf_min": minimum,
                "renderer": str(renderer),
                "policy": str(policy),
            },
            sort_keys=True,
        )
    )


def safe_member_path(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if not name or path.is_absolute() or ".." in path.parts:
        fail(f"unsafe archive member path: {name!r}")
    return path


def extract_archive(args: argparse.Namespace) -> None:
    archive = Path(args.archive).expanduser().resolve()
    destination = Path(args.dest).expanduser().resolve()
    destination.mkdir(parents=True, exist_ok=True)
    total_size = 0
    seen: set[PurePosixPath] = set()
    try:
        bundle = tarfile.open(archive, mode="r:gz")
    except (OSError, tarfile.TarError) as exc:
        fail(f"cannot open archive {archive}: {exc}")
    with bundle:
        members = bundle.getmembers()
        for member in members:
            path = safe_member_path(member.name)
            if path in seen:
                fail(f"duplicate archive member: {member.name!r}")
            seen.add(path)
            if not (member.isdir() or member.isfile()):
                fail(
                    f"archive links and special files are not allowed: {member.name!r}"
                )
            if member.isfile():
                total_size += member.size
                if total_size > MAX_UNPACKED_BYTES:
                    fail(f"archive expands beyond {MAX_UNPACKED_BYTES} bytes")

        for member in members:
            relative = safe_member_path(member.name)
            target = destination.joinpath(*relative.parts)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            source = bundle.extractfile(member)
            if source is None:
                fail(f"cannot read archive member: {member.name!r}")
            with source, target.open("wb") as output:
                shutil.copyfileobj(source, output)
            target.chmod(member.mode & 0o777)
    print(
        json.dumps(
            {"ok": True, "members": len(members), "unpacked_bytes": total_size},
            sort_keys=True,
        )
    )


def verify_checksum(args: argparse.Namespace) -> None:
    archive = Path(args.archive).expanduser().resolve()
    sums = Path(args.sums).expanduser().resolve()
    expected: str | None = None
    for raw_line in sums.read_text(encoding="utf-8").splitlines():
        parts = raw_line.strip().split(maxsplit=1)
        if len(parts) != 2:
            continue
        digest, filename = parts
        filename = filename.lstrip("*")
        if filename == archive.name:
            if expected is not None:
                fail(f"duplicate checksum entry for {archive.name}")
            expected = digest.lower()
    if expected is None or not re.fullmatch(r"[0-9a-f]{64}", expected):
        fail(f"missing valid SHA-256 entry for {archive.name}")
    digest = hashlib.sha256()
    with archive.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest()
    if actual != expected:
        fail(f"SHA-256 mismatch for {archive.name}")
    print(
        json.dumps(
            {"ok": True, "archive": str(archive), "sha256": actual}, sort_keys=True
        )
    )


def tree_digest(args: argparse.Namespace) -> None:
    root = Path(args.path).expanduser().resolve()
    digest = hashlib.sha256()
    for path in sorted(
        root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()
    ):
        relative = path.relative_to(root)
        if any(part in TREE_EXCLUDES for part in relative.parts):
            continue
        if path.is_symlink():
            fail(f"pack trees may not contain symlinks: {relative}")
        kind = b"d" if path.is_dir() else b"f"
        digest.update(kind + b"\0" + relative.as_posix().encode() + b"\0")
        if path.is_file():
            mode = stat.S_IMODE(path.stat().st_mode)
            digest.update(f"{mode:o}".encode() + b"\0")
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
    print(digest.hexdigest())


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate")
    validate.add_argument("--pack", required=True)
    validate.add_argument("--gaf-version", required=True)
    validate.add_argument("--allowed-login", required=True)
    validate.set_defaults(func=validate_pack)

    extract = subparsers.add_parser("extract")
    extract.add_argument("--archive", required=True)
    extract.add_argument("--dest", required=True)
    extract.set_defaults(func=extract_archive)

    checksum = subparsers.add_parser("checksum")
    checksum.add_argument("--archive", required=True)
    checksum.add_argument("--sums", required=True)
    checksum.set_defaults(func=verify_checksum)

    digest = subparsers.add_parser("tree-digest")
    digest.add_argument("--path", required=True)
    digest.set_defaults(func=tree_digest)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
