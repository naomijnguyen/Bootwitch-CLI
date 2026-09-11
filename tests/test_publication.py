#!/usr/bin/env python3
# @bootwitch:component
# Name: tests/test_publication.py
# Type: test
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Verify atomic project publication, collision refusal, and retained-stage recovery.
# Arguments: None.
# Output: unittest results.
# Returns: 0 when all tests pass; nonzero otherwise.
# Dependencies: Python 3 standard library, Bash, and toolkit dependencies.
# Reads: Toolkit source and native exclusive rename API.
# Writes: Disposable projects and test-only helper copies, removed after each test.
# Safety: Failure injection modifies only copied helpers; production has no injection switches.
# Example: python3 -B tests/test_publication.py
# @bootwitch:end
import ctypes
import errno
import os
from pathlib import Path
import runpy
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'lib/bootwitch/publish.py'
API = runpy.run_path(str(HELPER))


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='bootwitch-publication-')
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)

    def run_helper(self, source, target):
        return subprocess.run([sys.executable, str(HELPER), str(source), str(target)],
                              capture_output=True, text=True, timeout=15)

    def stage(self, name='stage'):
        source = self.home / name
        source.mkdir()
        (source / 'nested').mkdir()
        (source / 'nested/payload').write_bytes(b'complete\x00payload')
        (source / 'nested/payload').chmod(0o750)
        return source

    def toolkit(self, injection=''):
        toolkit = self.home / 'toolkit'
        shutil.copytree(ROOT, toolkit, ignore=shutil.ignore_patterns('node_modules', '.tools', '__pycache__', '.git'))
        helper = toolkit / 'lib/bootwitch/publish.py'
        helper.write_text(helper.read_text().replace('def publish(source, target):\n',
                                                    'def publish(source, target):\n' + injection))
        return toolkit

    def command(self, toolkit, name='demo'):
        return ['/bin/bash', str(toolkit / 'bin/bootwitch'), 'init', name,
                '--template', 'shell', '--root', str(self.home / 'projects'), '--no-git']

    def test_success_moves_inode_and_preserves_payload_and_mode(self):
        source = self.stage('stage with spaces')
        target = self.home / 'project with spaces'
        inode = source.stat().st_ino
        result = self.run_helper(source, target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(source.exists())
        self.assertEqual(target.stat().st_ino, inode)  # Directory was renamed, not copied.
        self.assertEqual((target / 'nested/payload').read_bytes(), b'complete\x00payload')
        self.assertEqual((target / 'nested/payload').stat().st_mode & 0o777, 0o750)

    def test_existing_destinations_are_never_replaced(self):
        for kind in ('empty', 'nonempty', 'file', 'symlink', 'dangling'):
            with self.subTest(kind=kind):
                source = self.stage('stage-' + kind)
                target = self.home / ('target-' + kind)
                if kind in ('empty', 'nonempty'):
                    target.mkdir()
                    if kind == 'nonempty':
                        (target / 'sentinel').write_text('user')
                elif kind == 'file':
                    target.write_text('user')
                else:
                    target.symlink_to(source if kind == 'symlink' else self.home / 'absent')
                inode = target.lstat().st_ino
                result = self.run_helper(source, target)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(target.lstat().st_ino, inode)
                self.assertTrue((source / 'nested/payload').exists())
                if kind == 'file':
                    self.assertEqual(target.read_text(), 'user')
                if kind == 'nonempty':
                    self.assertEqual([p.name for p in target.iterdir()], ['sentinel'])

    def test_native_errors_leave_source_and_no_destination(self):
        source = self.stage()
        target = self.home / 'target'
        for code in (errno.ENOSPC, errno.EACCES, errno.EXDEV, errno.ENOTSUP):
            def failed_rename(*args):
                ctypes.set_errno(code)
                return -1
            with patch.dict(API['publish'].__globals__, native_rename=lambda: failed_rename):
                with self.assertRaises(OSError) as error:
                    API['publish'](source, target)
                self.assertEqual(error.exception.errno, code)
            self.assertTrue(source.exists())
            self.assertFalse(target.exists())

    def test_unsupported_platform_and_missing_api_fail_closed(self):
        with patch.object(sys, 'platform', 'unsupported'):
            with self.assertRaises(RuntimeError):
                API['native_rename']()
        with patch.object(ctypes, 'CDLL', return_value=object()):
            with self.assertRaises(RuntimeError):
                API['native_rename']()

    def test_rejects_symlink_source_and_different_parents(self):
        source = self.stage()
        link = self.home / 'link'
        link.symlink_to(source)
        self.assertNotEqual(self.run_helper(link, self.home / 'target').returncode, 0)
        other = self.home / 'other'
        other.mkdir()
        self.assertNotEqual(self.run_helper(source, other / 'target').returncode, 0)
        self.assertTrue(source.exists())

    def test_failed_publication_retains_complete_stage_and_retry_works(self):
        toolkit = self.toolkit('    raise OSError(28, "injected publication failure")\n')
        result = subprocess.run(self.command(toolkit), capture_output=True, text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('prepared project retained:', result.stderr)
        self.assertNotIn('Created ', result.stdout)
        parent = self.home / 'projects'
        self.assertFalse((parent / 'demo').exists())
        stages = list(parent.glob('.bootwitch-demo.*'))
        self.assertEqual(len(stages), 1)
        self.assertTrue((stages[0] / 'README.md').is_file())
        self.assertTrue(os.access(stages[0] / 'wrappers/hello.command', os.X_OK))
        shutil.copy2(HELPER, toolkit / 'lib/bootwitch/publish.py')
        retry = result.stderr.split('retry publication: ', 1)[1].strip()
        recovered = subprocess.run(shlex.split(retry), capture_output=True, text=True, timeout=15)
        self.assertEqual(recovered.returncode, 0, recovered.stderr)
        self.assertFalse(stages[0].exists())
        self.assertTrue((parent / 'demo/README.md').is_file())

    def test_late_collision_preserves_rival_and_finished_stage(self):
        toolkit = self.toolkit('    os.mkdir(target)\n    with open(os.path.join(target, "sentinel"), "w") as rival:\n        rival.write("user")\n')
        result = subprocess.run(self.command(toolkit), capture_output=True, text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        target = self.home / 'projects/demo'
        self.assertEqual([p.name for p in target.iterdir()], ['sentinel'])
        self.assertEqual((target / 'sentinel').read_text(), 'user')
        self.assertEqual(len(list(target.parent.glob('.bootwitch-demo.*/README.md'))), 1)

    def test_competing_creators_publish_exactly_one_complete_tree(self):
        gate = self.home / 'gate'
        injection = ('    import time\n'
                     '    with open(source + ".ready", "w"):\n        pass\n'
                     '    while not os.path.exists({!r}):\n        time.sleep(0.01)\n').format(str(gate))
        toolkit = self.toolkit(injection)
        processes = [subprocess.Popen(self.command(toolkit), stdout=subprocess.PIPE,
                                      stderr=subprocess.PIPE, text=True) for _ in range(2)]
        try:
            deadline = time.monotonic() + 15
            parent = self.home / 'projects'
            while len(list(parent.glob('*.ready'))) != 2:
                if time.monotonic() > deadline:
                    self.fail('creators did not reach publication barrier')
                time.sleep(0.02)
            self.assertFalse((parent / 'demo').exists())
            gate.touch()
            outputs = [p.communicate(timeout=15) for p in processes]
            self.assertEqual(sorted(p.returncode for p in processes), [0, 1], outputs)
            self.assertTrue((parent / 'demo/README.md').is_file())
            self.assertFalse(list((parent / 'demo').glob('.bootwitch-*')))
            self.assertEqual(len([p for p in parent.glob('.bootwitch-demo.*') if p.is_dir()]), 1)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                    process.communicate()

    def test_interruption_before_publication_preserves_stage(self):
        toolkit = self.toolkit('    import signal\n    os.kill(os.getppid(), signal.SIGTERM)\n    raise OSError("interrupted before rename")\n')
        result = subprocess.run(self.command(toolkit), capture_output=True, text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        parent = self.home / 'projects'
        self.assertFalse((parent / 'demo').exists())
        self.assertEqual(len(list(parent.glob('.bootwitch-demo.*/README.md'))), 1)

    def test_lost_acknowledgement_does_not_remove_published_project(self):
        toolkit = self.toolkit()
        helper = toolkit / 'lib/bootwitch/publish.py'
        helper.write_text(helper.read_text().replace('            publish(*arguments)',
                          '            publish(*arguments)\n            raise OSError("injected lost acknowledgement")'))
        result = subprocess.run(self.command(toolkit), capture_output=True, text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('status uncertain', result.stderr)
        self.assertNotIn('retry publication:', result.stderr)
        self.assertTrue((self.home / 'projects/demo/README.md').is_file())
        self.assertFalse(list((self.home / 'projects').glob('.bootwitch-demo.*')))

    def test_missing_python_stops_before_writes(self):
        toolkit = self.toolkit()
        tools = self.home / 'tools'
        tools.mkdir()
        for command in ('dirname', 'tr'):
            (tools / command).symlink_to(shutil.which(command))
        environment = dict(os.environ, PATH=str(tools))
        result = subprocess.run(self.command(toolkit), env=environment, capture_output=True,
                                text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('python3 is required', result.stderr)
        self.assertFalse((self.home / 'projects').exists())

    def test_failed_preflight_writes_no_project_root(self):
        toolkit = self.toolkit()
        helper = toolkit / 'lib/bootwitch/publish.py'
        helper.write_text('import sys\nprint("exclusive rename unavailable", file=sys.stderr)\nsys.exit(1)\n')
        result = subprocess.run(self.command(toolkit), capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'projects').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
