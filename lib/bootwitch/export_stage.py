#!/usr/bin/env python3
"""Copy one validated public-export inventory into a private, marked run.

This creates a source snapshot, not a build, Git repository, or publication.
"""

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
import stat
import sys
import uuid

from public_export import inventory


ROOT_MARKER = ".bootwitch-export-output.json"
RUN_MARKER = ".bootwitch-export-run.json"
INVENTORY_MARKER = ".bootwitch-export-inventory.json"
ROOT_MARKER_DATA = {"version": 1, "purpose": "bootwitch-export-runs"}
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
FILE_FLAGS = os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_NONBLOCK", 0)


def _write_new_json(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(value, stream, sort_keys=True)
        stream.write("\n")


def _output_root(project, output_root):
    root = Path(output_root).absolute()
    if root.name != "export-runs":
        raise ValueError("output root must be named export-runs")
    # A direct link at the caller-controlled output boundary is ambiguous.
    # System temp roots (macOS /var -> /private/var) may themselves be linked.
    for path in (root, root.parent):
        if path.is_symlink():
            raise ValueError("output root and its parents must not be symlinks")
    resolved = root.resolve(strict=False)
    if resolved.is_relative_to(project) or project.is_relative_to(resolved):
        raise ValueError("project and export-runs root must be separate trees")
    if not root.exists():
        root.mkdir(mode=0o700)
        _write_new_json(root / ROOT_MARKER, ROOT_MARKER_DATA)
    elif not root.is_dir():
        raise ValueError("output root is not a directory")
    marker = root / ROOT_MARKER
    if marker.is_symlink() or not marker.is_file():
        raise ValueError("existing output root lacks a regular Bootwitch marker")
    if json.loads(marker.read_text(encoding="utf-8")) != ROOT_MARKER_DATA:
        raise ValueError("existing output root has an invalid Bootwitch marker")
    details = root.stat()
    if details.st_uid != os.getuid() or details.st_mode & 0o077:
        raise ValueError("output root must be owned by this user and private")
    return root


def _copy_verified(project_fd, source, destination, expected):
    parts = Path(source).parts
    parent_fd = os.dup(project_fd)
    try:
        for part in parts[:-1]:
            next_fd = os.open(part, DIRECTORY_FLAGS, dir_fd=parent_fd)
            os.close(parent_fd)
            parent_fd = next_fd
        source_fd = os.open(parts[-1], FILE_FLAGS, dir_fd=parent_fd)
        try:
            before = os.fstat(source_fd)
            if not stat.S_ISREG(before.st_mode):
                raise ValueError(f"source is not a regular file: {source}")
            digest = hashlib.sha256()
            count = 0
            destination_fd = os.open(destination,
                                     os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                     0o600)
            with os.fdopen(destination_fd, "wb") as target:
                while True:
                    chunk = os.read(source_fd, 1024 * 1024)
                    if not chunk:
                        break
                    target.write(chunk)
                    digest.update(chunk)
                    count += len(chunk)
            after = os.fstat(source_fd)
            identity = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")
            if (any(getattr(before, field) != getattr(after, field) for field in identity)
                    or count != expected["bytes"] or digest.hexdigest() != expected["sha256"]):
                raise ValueError(f"source changed during staging: {source}")
        finally:
            os.close(source_fd)
    finally:
        os.close(parent_fd)


def stage(project_root, output_root, *, after_inventory=None):
    """Return a marked run path; retain a failed run if copying has begun.

    ``after_inventory`` is a test-only hook to exercise copy-time races.
    """
    project = Path(project_root).resolve(strict=True)
    report = inventory(project)  # Invalid manifest creates no output directory.
    if after_inventory is not None:
        after_inventory()
    root = _output_root(project, output_root)
    run_id = f"run-{uuid.uuid4()}"
    run = root / run_id
    run.mkdir(mode=0o700)
    marker = {"version": 1, "run_id": run_id, "status": "failed",
              "created_at": datetime.now(timezone.utc).isoformat()}
    _write_new_json(run / RUN_MARKER, marker)
    _write_new_json(run / INVENTORY_MARKER, report)
    source_tree = run / "source"
    source_tree.mkdir(mode=0o700)
    project_fd = os.open(project, DIRECTORY_FLAGS)
    try:
        for item in report["files"]:
            target = source_tree.joinpath(*Path(item["output"]).parts)
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            _copy_verified(project_fd, item["source"], target, item)
        marker["status"] = "staged"
        temporary = run / ".bootwitch-export-run.next.json"
        _write_new_json(temporary, marker)
        os.replace(temporary, run / RUN_MARKER)
    finally:
        os.close(project_fd)
    return run


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2:
        print("Usage: export_stage.py PROJECT_ROOT OUTPUT_ROOT", file=sys.stderr)
        return 2
    try:
        print(stage(args[0], args[1]))
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"bootwitch-export-stage: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
