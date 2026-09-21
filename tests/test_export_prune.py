#!/usr/bin/env python3
"""Exercise export cleanup only inside disposable marked fixtures."""

from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
import importlib.util
from io import StringIO
import json
import os
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "lib/bootwitch/export_prune.py"
SPEC = importlib.util.spec_from_file_location("export_prune", MODULE_PATH)
export_prune = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(export_prune)
RUN_ID = "run-11111111-2222-4333-8444-555555555555"


class ExportPruneTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "export-runs"
        self.root.mkdir()
        (self.root / export_prune.ROOT_MARKER).write_text(
            json.dumps({"version": 1, "purpose": "bootwitch-export-runs"}), encoding="utf-8")
        self.old = datetime.now(timezone.utc) - timedelta(days=15)

    def run_fixture(self, name=RUN_ID, status="failed", age=None):
        run = self.root / name
        run.mkdir()
        (run / "payload.txt").write_text("fixture", encoding="utf-8")
        (run / export_prune.RUN_MARKER).write_text(json.dumps({
            "version": 1, "run_id": name, "status": status,
            "created_at": (age or self.old).isoformat(),
        }), encoding="utf-8")
        for path in (run / "payload.txt", run / export_prune.RUN_MARKER, run):
            os.utime(path, (self.old.timestamp(), self.old.timestamp()))
        return run

    def test_dry_run_keeps_eligible_run_and_apply_removes_it(self):
        run = self.run_fixture()
        output = StringIO()
        with redirect_stdout(output):
            self.assertEqual(export_prune.main([str(self.root)]), 0)
        self.assertIn("eligible (failed, untouched for 14+ days):", output.getvalue())
        self.assertTrue(run.exists())
        with redirect_stdout(StringIO()):
            self.assertEqual(export_prune.main([str(self.root), "--apply"]), 0)
        self.assertFalse(run.exists())
        self.assertTrue((self.root / export_prune.ROOT_MARKER).exists())

    def test_recent_or_successful_runs_are_preserved(self):
        recent = self.run_fixture("run-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                                  age=datetime.now(timezone.utc) - timedelta(days=7))
        successful = self.run_fixture(status="approved")
        self.assertEqual(export_prune.eligible_runs(self.root), [])
        with redirect_stdout(StringIO()):
            self.assertEqual(export_prune.main([str(self.root), "--apply"]), 0)
        self.assertTrue(recent.exists())
        self.assertTrue(successful.exists())

    def test_recent_edits_and_unmarked_directories_are_preserved(self):
        run = self.run_fixture()
        os.utime(run / "payload.txt", None)
        unmarked = self.root / "run-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
        unmarked.mkdir()
        self.assertEqual(export_prune.eligible_runs(self.root), [])
        self.assertTrue(run.exists())
        self.assertTrue(unmarked.exists())

    def test_symlink_run_and_unmarked_root_are_rejected(self):
        outside = Path(self.temporary.name) / "outside"
        outside.mkdir()
        (self.root / RUN_ID).symlink_to(outside, target_is_directory=True)
        self.assertEqual(export_prune.eligible_runs(self.root), [])
        self.assertTrue(outside.exists())
        with self.assertRaises(ValueError):
            export_prune.eligible_runs(outside)


if __name__ == "__main__":
    unittest.main()
