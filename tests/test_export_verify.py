#!/usr/bin/env python3
"""Exact-tree checks for marked public-export source snapshots."""

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[1] / "lib/bootwitch"
sys.path.insert(0, str(MODULE_DIR))
STAGE_SPEC = importlib.util.spec_from_file_location("export_stage", MODULE_DIR / "export_stage.py")
export_stage = importlib.util.module_from_spec(STAGE_SPEC)
STAGE_SPEC.loader.exec_module(export_stage)
VERIFY_SPEC = importlib.util.spec_from_file_location("export_verify", MODULE_DIR / "export_verify.py")
export_verify = importlib.util.module_from_spec(VERIFY_SPEC)
VERIFY_SPEC.loader.exec_module(export_verify)


class ExportVerifyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        base = Path(temporary.name)
        project = base / "project"
        (project / "exports").mkdir(parents=True)
        (project / "src").mkdir()
        (project / "src/app.txt").write_text("safe fixture", encoding="utf-8")
        (project / "exports/github-safe.json").write_text(json.dumps({
            "version": 1, "target": "github-safe", "files": [{
                "kind": "source", "source": "src/app.txt", "output": "app/app.txt",
            }],
        }), encoding="utf-8")
        output_root = base / "out" / "export-runs"
        output_root.parent.mkdir()
        self.run = export_stage.stage(project, output_root)
        self.output = self.run / "source/app/app.txt"

    def test_accepts_exact_tree_from_saved_inventory(self):
        self.assertEqual(export_verify.verify(self.run), 1)

    def test_rejects_extra_file_and_directory(self):
        (self.run / "source/app/extra.txt").write_text("extra", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unexpected staged file"):
            export_verify.verify(self.run)
        (self.run / "source/app/extra.txt").unlink()
        (self.run / "source/extra-dir").mkdir()
        os.chmod(self.run / "source/extra-dir", 0o700)
        with self.assertRaisesRegex(ValueError, "staged tree differs"):
            export_verify.verify(self.run)

    def test_rejects_changed_or_missing_file(self):
        self.output.write_text("altered", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "differs from saved inventory"):
            export_verify.verify(self.run)
        self.output.unlink()
        with self.assertRaisesRegex(ValueError, "staged tree differs"):
            export_verify.verify(self.run)

    def test_rejects_symlink_in_source_tree(self):
        outside = self.run.parent.parent / "outside.txt"
        outside.write_text("secret", encoding="utf-8")
        self.output.unlink()
        self.output.symlink_to(outside)
        with self.assertRaises(OSError):
            export_verify.verify(self.run)

    def test_rejects_failed_marker_or_missing_inventory(self):
        marker_path = self.run / export_stage.RUN_MARKER
        marker = json.loads(marker_path.read_text())
        marker["status"] = "failed"
        marker_path.write_text(json.dumps(marker), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not a staged"):
            export_verify.verify(self.run)
        marker["status"] = "staged"
        marker_path.write_text(json.dumps(marker), encoding="utf-8")
        (self.run / export_stage.INVENTORY_MARKER).unlink()
        with self.assertRaisesRegex(ValueError, "unexpected export run entry"):
            export_verify.verify(self.run)

    def test_rejects_public_file_mode(self):
        os.chmod(self.output, 0o644)
        with self.assertRaisesRegex(ValueError, "not a private regular file"):
            export_verify.verify(self.run)

    def test_rejects_tampered_inventory(self):
        inventory_path = self.run / export_stage.INVENTORY_MARKER
        inventory = json.loads(inventory_path.read_text())
        inventory["files"][0]["output"] = "../outside.txt"
        inventory_path.write_text(json.dumps(inventory), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "output must not"):
            export_verify.verify(self.run)


if __name__ == "__main__":
    unittest.main()
