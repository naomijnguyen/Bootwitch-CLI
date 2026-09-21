#!/usr/bin/env python3
"""Isolated staging tests; every fixture lives in a temporary directory."""

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[1] / "lib/bootwitch"
sys.path.insert(0, str(MODULE_DIR))
SPEC = importlib.util.spec_from_file_location("export_stage", MODULE_DIR / "export_stage.py")
export_stage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(export_stage)


class ExportStageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.project = self.base / "project"
        self.project.mkdir()
        (self.project / "exports").mkdir()
        (self.project / "src").mkdir()
        (self.project / "src/app.txt").write_text("safe fixture", encoding="utf-8")
        self.root = self.base / "out" / "export-runs"
        self.root.parent.mkdir()
        self.write_manifest()

    def write_manifest(self, source="src/app.txt", output="app/app.txt"):
        (self.project / "exports/github-safe.json").write_text(json.dumps({
            "version": 1, "target": "github-safe", "files": [{
                "kind": "source", "source": source, "output": output,
            }],
        }), encoding="utf-8")

    def test_stages_exact_declared_file_without_changing_project(self):
        before = (self.project / "src/app.txt").read_bytes()
        run = export_stage.stage(self.project, self.root)
        self.assertEqual(run.parent, self.root)
        self.assertEqual([p.relative_to(run).as_posix() for p in run.rglob("*") if p.is_file()],
                         [".bootwitch-export-run.json", "source/app/app.txt"])
        self.assertEqual((run / "source/app/app.txt").read_bytes(), before)
        self.assertEqual((run / "source/app/app.txt").stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.project / "src/app.txt").read_bytes(), before)
        marker = json.loads((run / export_stage.RUN_MARKER).read_text())
        self.assertEqual(marker["status"], "staged")
        self.assertEqual(marker["run_id"], run.name)
        self.assertEqual((self.root / export_stage.ROOT_MARKER).is_file(), True)
        self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)
        self.assertEqual(run.stat().st_mode & 0o777, 0o700)

    def test_invalid_manifest_creates_no_output(self):
        self.write_manifest(source="internal/notes.md")
        with self.assertRaises(ValueError):
            export_stage.stage(self.project, self.root)
        self.assertFalse(self.root.exists())

    def test_changed_source_leaves_marked_failed_run(self):
        def change():
            (self.project / "src/app.txt").write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "source changed"):
            export_stage.stage(self.project, self.root, after_inventory=change)
        runs = [path for path in self.root.iterdir() if path.is_dir()]
        self.assertEqual(len(runs), 1)
        marker = json.loads((runs[0] / export_stage.RUN_MARKER).read_text())
        self.assertEqual(marker["status"], "failed")

    def test_link_swap_leaves_failed_run_without_copying_target(self):
        outside = self.base / "secret.txt"
        outside.write_text("do not copy", encoding="utf-8")
        def relink():
            (self.project / "src/app.txt").unlink()
            (self.project / "src/app.txt").symlink_to(outside)
        with self.assertRaises(OSError):
            export_stage.stage(self.project, self.root, after_inventory=relink)
        runs = [path for path in self.root.iterdir() if path.is_dir()]
        self.assertEqual(len(runs), 1)
        self.assertEqual(json.loads((runs[0] / export_stage.RUN_MARKER).read_text())["status"],
                         "failed")
        self.assertFalse((runs[0] / "source/app/app.txt").exists())

    def test_refuses_unmarked_and_linked_output_roots(self):
        self.root.mkdir()
        with self.assertRaisesRegex(ValueError, "marker"):
            export_stage.stage(self.project, self.root)
        self.assertEqual(list(self.root.iterdir()), [])
        self.root.rmdir()
        self.root.symlink_to(self.project, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            export_stage.stage(self.project, self.root)

    def test_refuses_linked_parent_and_permissive_marked_root(self):
        link = self.base / "linked-out"
        link.symlink_to(self.root.parent, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlinks"):
            export_stage.stage(self.project, link / "export-runs")
        self.root.mkdir(mode=0o700)
        (self.root / export_stage.ROOT_MARKER).write_text(json.dumps(
            export_stage.ROOT_MARKER_DATA), encoding="utf-8")
        os.chmod(self.root, 0o755)
        with self.assertRaisesRegex(ValueError, "private"):
            export_stage.stage(self.project, self.root)

    def test_refuses_nested_source_and_output(self):
        with self.assertRaisesRegex(ValueError, "separate trees"):
            export_stage.stage(self.project, self.project / "export-runs")
        source_under_output = self.base / "nested" / "export-runs" / "project"
        source_under_output.mkdir(parents=True)
        (source_under_output / "exports").mkdir()
        (source_under_output / "src").mkdir()
        (source_under_output / "src/app.txt").write_text("fixture", encoding="utf-8")
        (source_under_output / "exports/github-safe.json").write_bytes(
            (self.project / "exports/github-safe.json").read_bytes())
        with self.assertRaisesRegex(ValueError, "separate trees"):
            export_stage.stage(source_under_output, source_under_output.parent)

    def test_can_create_another_run_in_marked_root(self):
        first = export_stage.stage(self.project, self.root)
        second = export_stage.stage(self.project, self.root)
        self.assertNotEqual(first, second)
        self.assertEqual(len([p for p in self.root.iterdir() if p.is_dir()]), 2)


if __name__ == "__main__":
    unittest.main()
