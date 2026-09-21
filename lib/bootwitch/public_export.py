#!/usr/bin/env python3
# @bootwitch:component
# Name: lib/bootwitch/public_export.py
# Type: script
# Dates: Created: 2026-09-21 | Last Updated: 2026-09-21
# Version: 0.1.0
# Purpose: Inventory explicitly selected GitHub-safe project files without staging or publishing.
# Arguments: PROJECT_ROOT; reads its exports/github-safe.json contract.
# Output: JSON paths, sizes, and hashes on stdout; validation errors on stderr.
# Returns: 0 on valid inventory, 1 on invalid input, 2 on invalid arguments.
# Dependencies: Python 3.9+ standard library.
# Reads: One project manifest and its explicitly selected regular files.
# Writes: Nothing.
# Safety: Rejects traversal, symlinks, missing files, duplicates, and private path classes; no file bodies in report.
# Example: python3 lib/bootwitch/public_export.py /path/to/project
# @bootwitch:end
"""Inventory an explicit, project-owned public export manifest.

This preflight does not copy, initialize Git, or publish anything. It is the
first fail-closed boundary for the reusable Bootwitch public-repo generator.
"""

import hashlib
import json
from pathlib import Path
import sys


FORBIDDEN_PARTS = {
    ".git", ".env", "agents", "agents.md", "internal", "interview", "interviews",
    "private", "private-assets", "recruiter", "secrets", "study-guides",
}
ALLOWED_KINDS = {"source", "example-content", "public-asset", "build-config"}
EXPORT_MANIFEST = Path("exports/github-safe.json")


def _relative_path(value, label):
    if not isinstance(value, str) or not value or "\\" in value:
        raise ValueError(f"{label} must be a nonempty POSIX relative path")
    path = Path(value)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in value.split("/")):
        raise ValueError(f"{label} must not be absolute or traverse directories")
    if any(part.lower() in FORBIDDEN_PARTS or part.lower().startswith(".env") for part in path.parts):
        raise ValueError(f"{label} enters a forbidden private location")
    return path


def inventory(project_root):
    root = Path(project_root).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("project root is not a directory")
    manifest_path = root / EXPORT_MANIFEST
    if (manifest_path.parent.is_symlink() or manifest_path.is_symlink()
            or not manifest_path.is_file()):
        raise ValueError("manifest must be a regular, non-symlink file")
    if not manifest_path.resolve(strict=True).is_relative_to(root):
        raise ValueError("manifest escapes project root")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or set(manifest) != {"version", "target", "files"}:
        raise ValueError("manifest must contain exactly version, target, and files")
    if manifest["version"] != 1 or manifest["target"] != "github-safe":
        raise ValueError("unsupported manifest version or target")
    if not isinstance(manifest["files"], list) or not manifest["files"]:
        raise ValueError("manifest needs at least one explicit file")

    seen_sources, seen_outputs, files = set(), set(), []
    for entry in manifest["files"]:
        if not isinstance(entry, dict) or set(entry) != {"source", "output", "kind"}:
            raise ValueError("each file must declare exactly source, output, and kind")
        if entry["kind"] not in ALLOWED_KINDS:
            raise ValueError("unsupported file kind")
        source = _relative_path(entry["source"], "source")
        output = _relative_path(entry["output"], "output")
        if str(source) in seen_sources or str(output) in seen_outputs:
            raise ValueError("duplicate source or output path")
        seen_sources.add(str(source))
        seen_outputs.add(str(output))
        physical = root / source
        if physical.is_symlink() or not physical.is_file():
            raise ValueError(f"missing or symlink source: {source}")
        resolved = physical.resolve(strict=True)
        if not resolved.is_relative_to(root):
            raise ValueError(f"source escapes project root: {source}")
        if any(parent.is_symlink() for parent in physical.parents if parent != root and parent.is_relative_to(root)):
            raise ValueError(f"source has a symlink parent: {source}")
        data = resolved.read_bytes()
        files.append({"kind": entry["kind"], "source": str(source),
                      "output": str(output), "bytes": len(data),
                      "sha256": hashlib.sha256(data).hexdigest()})
    return {"version": 1, "target": "github-safe", "files": files}


def main(argv):
    if len(argv) != 2:
        print("Usage: public_export.py PROJECT_ROOT", file=sys.stderr)
        return 2
    try:
        print(json.dumps(inventory(argv[1]), indent=2))
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"bootwitch-public-export: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
