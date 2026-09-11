#!/usr/bin/env python3
# @bootwitch:component
# Name: lib/bootwitch/publish.py
# Type: script
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.1.0
# Purpose: Atomically publish a staged project without replacing any destination.
# Arguments: --check, or STAGING DESTINATION (sibling directories).
# Output: Diagnostics on stderr; silent success.
# Returns: 0 on success; 1 on publication or capability failure; 2 for usage errors.
# Dependencies: Python 3 standard library; macOS renamex_np or Linux renameat2 with exclusive rename support.
# Reads: Staging directory metadata and native platform capability.
# Writes: Renames staging to destination in one filesystem operation; never copies or removes content.
# Safety: Refuses existing destinations in the native operation; no weaker fallback; failures retain staging.
# Example: python3 lib/bootwitch/publish.py /projects/.bootwitch-demo.ABC123 /projects/demo
# @bootwitch:end
"""Exclusive directory publication for trusted local project parents.

ABI references: https://man7.org/linux/man-pages/man2/rename.2.html
https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/stdio.h
"""
import ctypes
import errno
import os
import stat
import sys


def native_rename():
    """Load the platform's exclusive rename; never fall back to os.rename."""
    libc = ctypes.CDLL(None, use_errno=True)
    try:
        if sys.platform == "darwin":
            function = libc.renamex_np
            function.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
            function.restype = ctypes.c_int
            return lambda source, target: function(source, target, 0x00000004)  # RENAME_EXCL
        if sys.platform.startswith("linux"):
            function = libc.renameat2
            function.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int,
                                 ctypes.c_char_p, ctypes.c_uint]
            function.restype = ctypes.c_int
            # Absolute paths below make the directory descriptors irrelevant.
            return lambda source, target: function(-100, source, -100, target, 1)  # RENAME_NOREPLACE
    except AttributeError as error:
        raise RuntimeError("exclusive rename is unavailable in the system C library") from error
    raise RuntimeError("atomic publication requires macOS or Linux exclusive rename support")


def publish(source, target):
    source, target = os.path.abspath(source), os.path.abspath(target)
    if not stat.S_ISDIR(os.lstat(source).st_mode):
        raise ValueError("staging must be a real directory, not a symlink")
    if os.path.realpath(os.path.dirname(source)) != os.path.realpath(os.path.dirname(target)):
        raise ValueError("staging and destination must share a parent directory")
    rename = native_rename()
    if rename(os.fsencode(source), os.fsencode(target)) != 0:
        code = ctypes.get_errno()
        if code in (errno.ENOSYS, errno.EINVAL, errno.ENOTSUP):
            raise OSError(code, "exclusive rename unsupported; refusing unsafe fallback", target)
        raise OSError(code, os.strerror(code), target)


def main(arguments):
    if arguments != ["--check"] and len(arguments) != 2:
        print("Usage: publish.py --check | STAGING DESTINATION", file=sys.stderr)
        return 2
    try:
        if arguments == ["--check"]:
            native_rename()  # Filesystem support is checked by the actual operation.
        else:
            publish(*arguments)
    except (OSError, RuntimeError, ValueError) as error:
        print("bootwitch-publish: {}".format(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
