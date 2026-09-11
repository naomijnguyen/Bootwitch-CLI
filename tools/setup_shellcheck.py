#!/usr/bin/env python3
# @bootwitch:component
# Name: tools/setup_shellcheck.py
# Type: script
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.1.0
# Purpose: Install the pinned official ShellCheck binary locally with archive checksum verification.
# Arguments: --check verifies the installed version without downloading; no arguments installs.
# Output: Installed tool path or actionable error.
# Returns: 0 on success; nonzero on download, checksum, platform, or validation failure.
# Dependencies: Python 3 standard library; network access only for explicit installation.
# Reads: tools/shellcheck.json and official GitHub release archive.
# Writes: .tools/bin/shellcheck through a temporary file; no global installation.
# Safety: Verifies pinned SHA-256 before reading the archive; copies only one regular binary member, never extracts paths or links.
# Example: python3 tools/setup_shellcheck.py
# @bootwitch:end
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import subprocess
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def install(archive, checksum, version, target):
    if hashlib.sha256(archive).hexdigest() != checksum:
        raise ValueError('ShellCheck archive checksum mismatch')
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:xz') as bundle:
        member = bundle.getmember('shellcheck-v{}/shellcheck'.format(version))
        if not member.isfile():
            raise ValueError('ShellCheck binary must be a regular archive member')
        with bundle.extractfile(member) as stream:
            binary = stream.read()
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.shellcheck-', dir=str(target.parent))
    try:
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(binary)
        os.chmod(temporary, 0o755)
        check(Path(temporary), version)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def check(target, version):
    if not target.is_file():
        raise ValueError('ShellCheck is required. Run make setup first.')
    result = subprocess.run([str(target), '--version'], check=True, capture_output=True, text=True)
    if 'version: ' + version not in result.stdout.splitlines():
        raise ValueError('Unexpected ShellCheck version. Run make setup.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    arguments = parser.parse_args()
    config = json.loads((ROOT / 'tools/shellcheck.json').read_text())
    target = ROOT / '.tools/bin/shellcheck'
    version = config['version']
    if arguments.check:
        check(target, version)
        return
    machine = {'arm64': 'aarch64', 'AMD64': 'x86_64'}.get(platform.machine(), platform.machine())
    name = platform.system().lower() + '.' + machine
    if name not in config['sha256']:
        raise ValueError('Unsupported ShellCheck platform: ' + name)
    url = ('https://github.com/koalaman/shellcheck/releases/download/v{0}/'
           'shellcheck-v{0}.{1}.tar.xz').format(version, name)
    with urllib.request.urlopen(url, timeout=60) as response:
        archive = response.read()
    install(archive, config['sha256'][name], version, target)
    print('Installed ShellCheck {}: {}'.format(version, target))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, tarfile.TarError, subprocess.SubprocessError) as error:
        raise SystemExit('ShellCheck setup: ' + str(error))
