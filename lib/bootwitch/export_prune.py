#!/usr/bin/env python3
"""Preview or prune old, failed Bootwitch export runs in a marked output root."""

import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import shutil
import stat
import sys


ROOT_MARKER = ".bootwitch-export-output.json"
RUN_MARKER = ".bootwitch-export-run.json"
RETENTION = timedelta(days=14)
RUN_NAME = re.compile(r"run-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\Z")


def _read_marker(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"missing or linked marker: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _safe_tree_age(run, cutoff):
    """Do not prune a run containing recently touched or linked material."""
    for path in (run, *run.rglob("*")):
        details = path.lstat()
        if stat.S_ISLNK(details.st_mode) or not (
            stat.S_ISREG(details.st_mode) or stat.S_ISDIR(details.st_mode)
        ):
            return False
        if datetime.fromtimestamp(details.st_mtime, timezone.utc) > cutoff:
            return False
    return True


def eligible_runs(output_root, now=None):
    root = Path(output_root)
    if root.name != "export-runs" or root.is_symlink() or not root.is_dir():
        raise ValueError("output root must be an existing non-symlink export-runs directory")
    root = root.resolve(strict=True)
    marker = _read_marker(root / ROOT_MARKER)
    if marker != {"version": 1, "purpose": "bootwitch-export-runs"}:
        raise ValueError("output root is not marked for Bootwitch export runs")

    cutoff = (now or datetime.now(timezone.utc)) - RETENTION
    eligible = []
    for run in sorted(root.iterdir()):
        if not RUN_NAME.fullmatch(run.name) or run.is_symlink() or not run.is_dir():
            continue
        try:
            details = _read_marker(run / RUN_MARKER)
            if set(details) != {"version", "run_id", "status", "created_at"}:
                continue
            if details["version"] != 1 or details["run_id"] != run.name or details["status"] != "failed":
                continue
            created_at = datetime.fromisoformat(details["created_at"])
            if created_at.tzinfo is None or created_at.astimezone(timezone.utc) > cutoff:
                continue
            if _safe_tree_age(run, cutoff):
                eligible.append(run)
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            continue
    return eligible


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_root", help="marked Bootwitch export-runs directory")
    parser.add_argument("--apply", action="store_true", help="remove eligible failed runs")
    args = parser.parse_args(argv)
    try:
        runs = eligible_runs(args.output_root)
        if args.apply and not shutil.rmtree.avoids_symlink_attacks:
            raise ValueError("this platform lacks symlink-safe directory removal")
        for run in runs:
            if args.apply:
                # Recheck just before deletion; this is a cooperative local cleanup,
                # not a boundary against hostile concurrent filesystem mutation.
                if run not in eligible_runs(args.output_root):
                    continue
                shutil.rmtree(run)
            print(f"{'removed' if args.apply else 'eligible (failed, untouched for 14+ days)'}: {run}")
        if not runs:
            print("No eligible failed export runs.")
        return 0
    except (OSError, ValueError) as error:
        print(f"bootwitch-export-prune: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
