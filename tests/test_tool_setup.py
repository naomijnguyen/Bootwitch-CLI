#!/usr/bin/env python3
# @bootwitch:component
# Name: tests/test_tool_setup.py
# Type: test
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.1.0
# Purpose: Verify checksum refusal and bounded archive handling for local ShellCheck setup.
# Arguments: None.
# Output: unittest results.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Python 3 standard library.
# Reads: Tool setup implementation and generated in-memory archives.
# Writes: Owned temporary tool directory only; no network requests.
# Safety: Tests do not execute archive contents; version check is replaced in the successful extraction test.
# Example: python3 -B tests/test_tool_setup.py
# @bootwitch:end
import hashlib
import io
from pathlib import Path
import runpy
import tarfile
import tempfile
import unittest
from unittest.mock import patch

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/setup_shellcheck.py'))


class ToolSetupTests(unittest.TestCase):
    def archive(self, link=False):
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode='w:xz') as bundle:
            binary = tarfile.TarInfo('shellcheck-v1/shellcheck')
            if link:
                binary.type = tarfile.SYMTYPE
                binary.linkname = '../../outside'
                bundle.addfile(binary)
            else:
                binary.size = 4
                bundle.addfile(binary, io.BytesIO(b'tool'))
            unrelated = tarfile.TarInfo('../../outside')
            unrelated.size = 3
            bundle.addfile(unrelated, io.BytesIO(b'bad'))
        return data.getvalue()

    def test_bad_checksum_preserves_existing_install(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'shellcheck'
            target.write_bytes(b'previous')
            with self.assertRaisesRegex(ValueError, 'checksum'):
                API['install'](self.archive(), 'invalid', '1', target)
            self.assertEqual(target.read_bytes(), b'previous')

    def test_symlink_binary_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'shellcheck'
            archive = self.archive(link=True)
            with self.assertRaisesRegex(ValueError, 'regular'):
                API['install'](archive, hashlib.sha256(archive).hexdigest(), '1', target)
            self.assertFalse(target.exists())

    def test_only_expected_binary_is_written(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'bin/shellcheck'
            archive = self.archive()
            with patch.dict(API['install'].__globals__, check=lambda *args: None):
                API['install'](archive, hashlib.sha256(archive).hexdigest(), '1', target)
            self.assertEqual(target.read_bytes(), b'tool')
            self.assertEqual(sorted(str(p.relative_to(directory)) for p in Path(directory).rglob('*')),
                             ['bin', 'bin/shellcheck'])
            self.assertEqual(target.stat().st_mode & 0o777, 0o755)

    def test_missing_tool_is_an_error(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'make setup'):
                API['check'](Path(directory) / 'missing', '1')


if __name__ == '__main__':
    unittest.main(verbosity=2)
