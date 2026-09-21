#!/usr/bin/env python3
"""Verify an isolated export source snapshot against its saved inventory.

This checks local stage integrity, not whether file contents are safe to publish.
"""

import hashlib
import json
import os
from pathlib import Path
import stat
import sys

from export_prune import RUN_NAME
from export_stage import INVENTORY_MARKER, ROOT_MARKER, ROOT_MARKER_DATA, RUN_MARKER
from public_export import ALLOWED_KINDS, _relative_path


def _private_directory(path):
    details = path.lstat()
    if not stat.S_ISDIR(details.st_mode) or details.st_mode & 0o077:
        raise ValueError(f"not a private directory: {path}")


def _read_json_file(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as stream:
        details = os.fstat(stream.fileno())
        if not stat.S_ISREG(details.st_mode) or details.st_mode & 0o077:
            raise ValueError(f"not a private regular file: {path}")
        return json.load(stream)


def _expected_files(report):
    if (not isinstance(report, dict) or set(report) != {"version", "target", "files"}
            or report["version"] != 1 or report["target"] != "github-safe"
            or not isinstance(report["files"], list) or not report["files"]):
        raise ValueError("invalid saved export inventory")
    expected = {}
    casefolded = set()
    for item in report["files"]:
        if not isinstance(item, dict) or set(item) != {"kind", "source", "output", "bytes", "sha256"}:
            raise ValueError("invalid saved inventory entry")
        if item["kind"] not in ALLOWED_KINDS:
            raise ValueError("invalid saved inventory kind")
        _relative_path(item["source"], "source")
        output = _relative_path(item["output"], "output").as_posix()
        size, digest = item["bytes"], item["sha256"]
        if (not isinstance(size, int) or isinstance(size, bool) or size < 0
                or not isinstance(digest, str) or len(digest) != 64
                or any(character not in "0123456789abcdef" for character in digest)):
            raise ValueError("invalid saved inventory digest or size")
        folded = output.casefold()
        if folded in casefolded:
            raise ValueError("duplicate saved inventory output")
        casefolded.add(folded)
        expected[output] = (size, digest)
    return expected


def _hash_private_file(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_NONBLOCK", 0))
    with os.fdopen(descriptor, "rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_mode & 0o077:
            raise ValueError(f"not a private regular file: {path}")
        digest = hashlib.sha256()
        size = 0
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
            size += len(chunk)
        after = os.fstat(stream.fileno())
        identity = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")
        if any(getattr(before, field) != getattr(after, field) for field in identity):
            raise ValueError(f"file changed during verification: {path}")
    return size, digest.hexdigest()


def verify(run_path):
    """Return file count after checking the marked run and its exact source tree."""
    run = Path(run_path).absolute()
    root = run.parent
    if root.name != "export-runs" or not RUN_NAME.fullmatch(run.name):
        raise ValueError("expected a direct run-<uuid> child of export-runs")
    _private_directory(root)
    _private_directory(run)
    if _read_json_file(root / ROOT_MARKER) != ROOT_MARKER_DATA:
        raise ValueError("invalid export root marker")
    marker = _read_json_file(run / RUN_MARKER)
    if (not isinstance(marker, dict) or set(marker) != {"version", "run_id", "status", "created_at"}
            or marker["version"] != 1 or marker["run_id"] != run.name
            or marker["status"] != "staged" or not isinstance(marker["created_at"], str)):
        raise ValueError("run is not a staged Bootwitch export")
    if {entry.name for entry in run.iterdir()} != {RUN_MARKER, INVENTORY_MARKER, "source"}:
        raise ValueError("unexpected export run entry")
    expected = _expected_files(_read_json_file(run / INVENTORY_MARKER))
    source = run / "source"
    _private_directory(source)
    expected_directories = {"."}
    for output in expected:
        parent = Path(output).parent
        while parent != Path("."):
            expected_directories.add(parent.as_posix())
            parent = parent.parent
    actual = {}
    actual_directories = set()
    for directory, subdirectories, files in os.walk(source, followlinks=False):
        relative_directory = Path(directory).relative_to(source).as_posix()
        actual_directories.add(relative_directory)
        _private_directory(Path(directory))
        for name in subdirectories:
            _private_directory(Path(directory) / name)
        for name in files:
            path = Path(directory) / name
            relative = path.relative_to(source).as_posix()
            if relative not in expected:
                raise ValueError(f"unexpected staged file: {relative}")
            actual[relative] = _hash_private_file(path)
    if actual_directories != expected_directories or set(actual) != set(expected):
        raise ValueError("staged tree differs from saved inventory")
    for output, measured in actual.items():
        if measured != expected[output]:
            raise ValueError(f"staged file differs from saved inventory: {output}")
    return len(actual)


def main(argv=None):
    arguments = sys.argv[1:] if argv is None else argv
    if len(arguments) != 1:
        print("Usage: export_verify.py RUN_PATH", file=sys.stderr)
        return 2
    try:
        count = verify(arguments[0])
        print(f"Verified {count} staged files; not approved for publication")
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"bootwitch-export-verify: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
