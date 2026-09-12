# Filesystem safety and test isolation

Template names must be safe single directory names; symlinked template roots and
selected template directories are rejected.
Script creation rejects symlinked `scripts`, `src`, or `tests` destination
areas.

These checks assume trusted local project trees and do not defend against another
process actively replacing parent directories during a command.

The initializer checks Python 3 and the native exclusive rename API before writes,
then completes template copying, metadata, executable setup, and optional Git
initialization in a sibling staging folder. `lib/bootwitch/publish.py` publishes
that folder in one exclusive rename operation. There is no final project copy:
the requested name appears with the complete prepared contents, or publication
fails without creating a partial project there. Existing files, directories, and
symlinks are refused, including destinations created during preparation.

Preparation failures clean owned staging. Publication failures retain the completed
hidden staging folder and print a shell-quoted retry command. Resolve the reported
cause before running that command; a name collision still requires a different
unused destination or manual resolution of the existing path. Never replace an
existing project merely to make a retry succeed. Success leaves no staging folder.
An interruption around the rename can leave either the prepared stage or the complete
destination; inspect both paths if success was not reported.

The helper uses macOS `renamex_np(RENAME_EXCL)` or Linux
`renameat2(RENAME_NOREPLACE)` through Python's standard-library `ctypes`. It
refuses unsupported APIs/filesystems and cross-parent recovery attempts; it never
falls back to ordinary rename or copy.

Atomic visibility is not a power-loss durability guarantee. These semantics assume
trusted local parent directories and filesystems that honor the exclusive rename
operation.

The regression suite covers native rename, destination collisions, competing
creators, publication failure and retry, missing capability, and interruption.
CI provisions Python 3 and verified ShellCheck on both macOS and Ubuntu runners.
See the repository's CI runs:
<https://github.com/naomijnguyen/bootwitch/actions/workflows/ci.yml>.

New scripts use a no-clobber write to refuse regular files that arrive during
rendering. A write or permission failure may leave a file requiring inspection;
README refresh runs only after successful creation. Script publication is not an
atomic content swap.

Bundled shell mutation tests run in a disposable project copy and leave the
original project's files and permissions intact. They choose an unused fixture
name and refuse copied trees containing symlinks, to prevent fixture operations
from following links outside the copy.

Tool setup uses the [official ShellCheck release](https://github.com/koalaman/shellcheck/releases/tag/v0.11.0). The previous npm
wrapper was removed because its dependency tree included an unpatched
archive-extraction advisory. No npm dependencies remain in this toolkit.

Custom test suites remain responsible for their own side effects.

