#!/usr/bin/env python3
"""Fail-closed inventory tests for the reusable public export boundary."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "lib/bootwitch/public_export.py"
SPEC = importlib.util.spec_from_file_location("public_export", MODULE_PATH)
public_export = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(public_export)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "src").mkdir()
        (self.root / "exports").mkdir()
        (self.root / "src/app.txt").write_text("safe fixture", encoding="utf-8")
        self.entries = [{"kind": "source", "source": "src/app.txt", "output": "app.txt"}]

    def check(self, entries=None):
        manifest = {"version": 1, "target": "github-safe",
                    "files": self.entries if entries is None else entries}
        (self.root / "exports/github-safe.json").write_text(json.dumps(manifest), encoding="utf-8")
        return public_export.inventory(self.root)

    def test_explicit_source_inventory_has_no_file_body(self):
        report = self.check()
        self.assertEqual(report["files"][0]["output"], "app.txt")
        self.assertNotIn("safe fixture", json.dumps(report))

    def test_rejects_missing_and_traversal(self):
        for source in ("src/missing.txt", "../outside.txt"):
            with self.subTest(source=source), self.assertRaises(ValueError):
                self.check([{**self.entries[0], "source": source}])

    def test_rejects_private_source_and_output(self):
        for field, value in (("source", "internal/note.md"),
                             ("output", "AGENTS/notes.md"),
                             ("source", "AGENTS.md"),
                             ("output", "AGENTS.md")):
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.check([{**self.entries[0], field: value}])

    def test_does_not_use_deployment_or_content_manifest(self):
        (self.root / "deployments").mkdir()
        (self.root / "deployments/example.json").write_text(
            json.dumps({"version": 1, "contentPack": "example"}), encoding="utf-8")
        (self.root / "content-packs").mkdir()
        (self.root / "content-packs/manifest.json").write_text(
            json.dumps({"version": 1, "documents": []}), encoding="utf-8")
        with self.assertRaises(ValueError):
            public_export.inventory(self.root)

    def test_rejects_symlink_source(self):
        (self.root / "src/link.txt").symlink_to(self.root / "src/app.txt")
        with self.assertRaises(ValueError):
            self.check([{**self.entries[0], "source": "src/link.txt"}])

    def test_rejects_duplicate_output(self):
        with self.assertRaises(ValueError):
            self.check(self.entries * 2)


if __name__ == "__main__":
    unittest.main()
