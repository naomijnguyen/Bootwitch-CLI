# Bootwitch

Current version: `v0.2.0`

Bootwitch is a small, portable project scaffolder for macOS and Linux. It turns
a project idea into a consistent local workspace with predictable folders,
starter documentation, executable wrappers, and project-local support modules.

The casual version: Bootwitch is the thing I wanted when small automation
projects kept turning into mystery folders. It gives each new project obvious
front doors, keeps paths from breaking when scripts move, and leaves readable
notes beside the code so future-me can remember what is going on.

The current pre-public development line starts with two templates:

- `base`: a clean, language-neutral project layout.
- `shell`: the base layout plus a Bash entry point, logging, platform detection,
  and shell-focused tests.

Bootwitch emphasizes local safety and portability. It validates project names,
refuses existing destinations, assembles new projects in a staging directory,
and copies reusable modules into each generated project instead of depending on
machine-specific shared paths. It does not perform cloud sync, privileged
installation, background service setup, remote publishing, or automatic commits.

## Install

### Homebrew

The easiest installation path for macOS (and Linuxbrew) is Homebrew:

```sh
brew install --formula https://raw.githubusercontent.com/naomijnguyen/bootwitch/main/Formula/bootwitch.rb
```

To confirm installation:

```sh
bootwitch help
bootwitch list
```

Bootwitch requires Bash and Python 3 at runtime. Git is required for default project initialization (`bootwitch init`/`summon`).

For a release package update workflow, run:

```sh
bash tools/bump-brew-formula.sh v0.2.1
```

This fetches the new release tarball, computes SHA-256, and updates `Formula/bootwitch.rb` in one step.

## Quick start

Run Bootwitch commands from the Bootwitch code folder, such as this repository's
`CLI-Scaffold` directory:

```sh
cd /path/to/CLI-Scaffold
```

For a short, reproducible walkthrough, see [the demo](docs/demo.md).

From there, use the CLI to inspect the available templates and create a project:

```sh
./bin/bootwitch list
./bin/bootwitch templates
./bin/bootwitch wizard
./bin/bootwitch init my-project --template shell
./bin/bootwitch summon
```

Bootwitch creates projects under `~/Developer/Projects` by default. Use `--root`
to choose another parent directory, `--no-git` to skip Git initialization, or
`--dry-run` to preview an operation without writing anything.

The Bootwitch code folder and the generated project folder are separate:

```text
/path/to/CLI-Scaffold/             Bootwitch itself; run ./bin/bootwitch here.
~/Developer/Projects/my-project/   Generated project; run wrappers here.
```

So this command:

```sh
./bin/bootwitch init my-project --template shell
```

creates:

```text
~/Developer/Projects/my-project
```

To create the project somewhere else, pass the parent directory with `--root`:

```sh
./bin/bootwitch init my-project --template shell --root ~/Desktop
```

`wizard` checks the local environment and reports the Bootwitch version,
platform, Bash, Git, optional developer tools, and default project root.
`doctor` is kept as a conventional alias for the same check.

`list` is the short template list. `templates` is the fuller overview that shows
what each template creates.

`summon` is the guided project creator. It asks for the project name, template,
project root, and whether to initialize Git, then calls the same safe generation
path as `init`.

For example:

```sh
./bin/bootwitch init hello-bootwitch --template shell --root /tmp --no-git
```

During project creation, Bootwitch prints small setup messages such as making
the project directory, copying templates, writing metadata, filling tokens, and
making commands clickable. The messages are there so a first run feels visible
without adding hidden installs, cloud sync, or background services.

## Using A Generated Project

The `shell` template creates a project with clickable `.command` wrappers under
`wrappers/`. On macOS, these can be double-clicked in Finder or run from
Terminal.

| Wrapper | Use it for |
| --- | --- |
| `hello.command` | Friendly first-click greeting. |
| `initialize_project.command` | Prepare folders, permissions, and generated README documentation. |
| `run.command` | Run the starter project workflow. |
| `run_with_pauses.command` | Run the workflow and pause after checkpoints. |
| `new_script.command` | Create a consistently formatted script from the project template. |
| `build_readme.command` | Refresh the generated README section from annotations. |
| `make_executable.command` | Safely make one project-owned script executable. |

The same actions can be run from Terminal:

```sh
cd ~/Developer/Projects/my-project
./wrappers/hello.command
./wrappers/initialize_project.command
./wrappers/run.command
```

They can also be launched by absolute path from somewhere else:

```sh
cd /
~/Developer/Projects/my-project/wrappers/run.command
```

Even though the command starts from `/`, the generated project still writes its
report to `~/Developer/Projects/my-project/output/run-report.txt` and its log to
`~/Developer/Projects/my-project/logs/project.log`.

Inside a generated shell project, create consistently formatted scripts with:

```sh
./scripts/new-script.sh backup-data
./scripts/new-script.sh parse-results src
```

Generated scripts include a metadata header, strict Bash settings, project-root
discovery, the standard logging helper, and a `main` function.

The same universal header shape is used by bundled scripts, sourced modules,
wrappers, and tests. Required fields describe identity, dates/version, purpose,
inputs and outputs, dependencies, reads/writes, safety boundaries, and an example.
Runnable files show `set -e`, `set -u`, and `set -o pipefail` separately
and do not replace `IFS` globally.

## Generated Documentation

Shell projects combine human-authored README text with a marked reference built
from project facts in `project.header` and script annotations.

The workflow is **create a script to refresh the README automatically; edit its
header and rebuild when its behavior changes**. Keep the
explanation beside the code; Bootwitch turns those marked comments into the
project's component reference.

From the root of a generated shell project:

```sh
bash scripts/new-script.sh sample-task scripts
# After later edits to the script header:
bash wrappers/build_readme.command
```

The first command creates `scripts/sample-task.sh` with a populated starter
header and immediately refreshes the README, whether called directly or through
`wrappers/new_script.command`. Choose an unused name when repeating the example:
the generator refuses to overwrite an existing script. The second command is for
refreshing documentation after later header edits.

If script creation succeeds but the README refresh fails, the script stays in
place. The generator reports both outcomes, prints a retry command, and returns
status 3. Fix the reported builder problem and retry the README command; do not
recreate the script. The automatic refresh happens on creation, not each time the
new script runs.

For example, this excerpt from a script header:

```bash
# @bootwitch:component
# Name: sample-task.sh
# Type: script
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.1.0
# Purpose: Prepare project runtime directories and log the start of a custom workflow.
# @bootwitch:end
```

produces a component entry like this:

> **`sample-task.sh`**
>
> - **Type:** script
> - **Dates:** Created: 2026-09-11 | Last Updated: 2026-09-11
> - **Version:** 0.1.0
> - **Purpose:** Prepare project runtime directories and log the start of a custom workflow.

These dates are illustrative; a newly generated script receives its own creation
date. The complete header also documents arguments, output, return behavior,
dependencies, reads, writes, safety, and an example command.

As you implement the script, update its header to describe what it actually does.
Preserve Created, update Last Updated and Version when editing, then run
`bash wrappers/build_readme.command` again. The builder reads the marked comments
as text: it does not execute the documented scripts, infer behavior from their
code, or change their dates and versions. Header edits appear on the next rebuild;
they are not synchronized automatically.

The builder discovers `.sh` and `.command` files recursively in `wrappers/`,
`modules/`, `scripts/`, `src/`, and `tests/`. It includes marked
`@bootwitch:component` and `@bootwitch:function` blocks; ordinary unmarked comments
are not exported. Keep each header field on one line.

Only the region between the README's Bootwitch documentation markers is replaced.
Text outside it, including this kind of walkthrough, stays human-authored. The
builder rejects missing, duplicate, or reversed marker pairs before changing the
README. It also prepares the project's runtime folders as needed.

## Adaptive Paths

Generated shell scripts do not depend on the folder where the user happened to
run them. Each script starts by resolving its own location, then walks upward
until it finds `.bootwitch/project.conf`. Once the project root is found, paths
such as `logs/`, `cache/`, `temp/`, and `output/` are derived from that root.

This is why a wrapper can be clicked in Finder, run from inside the generated
project, or run from a totally different current folder. The script opens from
where it lives, not from where the terminal happens to be standing.

The practical result is:

- a script can be launched from Finder or Terminal;
- a generated script can move deeper inside the same project and still work;
- a script moved outside the project stops instead of guessing at paths;
- logs and reports stay inside the project that produced them.

## Development

Bootwitch keeps runtime dependencies small and treats quality tools separately.

Runtime:

- Bash 3.2+
- Python 3 with its standard library for toolkit project creation (not generated shell-project runtime).
- macOS or Linux with native exclusive rename support on the destination filesystem. Unsupported publication fails without a copy fallback.
- Git, unless using `--no-git`

Recommended development tools:

- ShellCheck (required for `make check`; installed locally by `make setup`)
- shfmt
- Bats

```sh
make setup
make check
```

`make check` requires the pinned local ShellCheck and runs syntax, integration,
publication, and tool-setup tests. Missing lint tooling is an error, never a
skipped success. `make setup` explicitly downloads official ShellCheck 0.11.0,
checks the archive against committed SHA-256 values, and installs only the binary
under `.tools/bin/`. It uses Python standard-library code and does not install
global packages. The same setup runs in the macOS/Linux CI matrix.
The Bash code targets the Bash 3.2 feature set shipped with macOS.

## Wrapper Names

The current wrapper names are intentionally literal so they are easy to inspect
and document before the first public release. Friendlier aliases may be added
later, but the underlying behavior should stay obvious:

- `hello.command` is the first-click welcome.
- `run.command` is the normal run button.
- `initialize_project.command` is setup and documentation refresh.
- `build_readme.command` is documentation-only refresh.
- `new_script.command` creates a new annotated script.
- `make_executable.command` changes permissions only for safe project-owned
  scripts.

## Technical overview

Bootwitch is implemented as a Bash CLI with an explicit command dispatcher. The
entry point in `bin/bootwitch` resolves its installation directory, loads the
core library from that trusted path, and routes commands through an allowlisted
`case` statement.

Project generation uses a template overlay model:

1. Copy the `base` template into a temporary staging directory.
2. Overlay a specialized template such as `shell`.
3. Write plain-text project metadata to `.bootwitch/project.conf`.
4. Replace documentation tokens such as project name, creation date, and
   Bootwitch version.
5. Mark generated shell entry points executable.
6. Optionally initialize an independent local Git repository.
7. Publish the complete staging directory using an atomic exclusive rename. An existing destination is refused by the operating system.

The shell starter demonstrates the wrapper/module pattern. Wrappers in
`wrappers/` are short, clickable entry points. Modules in `modules/` contain the
reusable behavior for root discovery, path setup, logging, checkpoints,
platform detection, permissions, and documentation extraction. Runtime scripts
derive all operational paths from the discovered project root.

For more detail, see `ARCHITECTURE.md` and `docs/template-authoring.md`.

## Portfolio framing

Bootwitch is best presented as an AI-assisted developer-tooling project focused
on workflow design, safe automation, documentation, and technical learning. It
demonstrates practical engineering concepts including command dispatch,
defensive input validation, staged filesystem writes, project-local dependency
snapshots, shell portability, generated documentation, observability, and
integration testing.

The strongest demo is a small generated project that shows:

- one command creating a complete workspace;
- a wrapper running the project workflow;
- checkpoints appearing after successful steps;
- logs and reports written under project-owned folders;
- a moved script still finding the project root;
- tests proving overwrite protection and path handling.

## Project status

Bootwitch deliberately excludes mountctl, launchd agents, cloud
synchronization, general application templates, and portfolio generation until
the core scaffolder is stable. The current repository passes syntax checks,
integration tests, and generated-project tests through `make check`; required
linting and formatting checks run when their developer tools are installed.

### Reliable README builds

The current header format is `# Dates: Created: YYYY-MM-DD | Last Updated: YYYY-MM-DD`,
followed by `# Version: ...`. Legacy separate Created and Last Updated fields still
render. If both formats exist, Dates takes precedence.

The builder validates marked blocks and requires a nonempty Name, matching block
markers, and unique field names within each block. Unmarked comments are ignored.
Required project facts are PROJECT_PURPOSE, PROJECT_TYPE, PROJECT_VERSION,
PROJECT_STATUS, and PRIMARY_WRAPPER; missing or blank values stop the build.

Files are discovered in stable bytewise path order within each component folder.
The completed README is staged on the same filesystem and atomically replaces the
original only after validation and rendering succeed. Its permission mode is
preserved, and staging files are cleaned up on ordinary failures and catchable
signals. A failed build before publication leaves the previous README intact.
This does not lock out simultaneous human edits; avoid editing the README while
rebuilding it. Existing symbolic-link READMEs are rejected explicitly.

### Filesystem safety and test isolation

Template names must be safe single directory names; symlinked template roots and
selected template directories are rejected. Script creation rejects symlinked
`scripts`, `src`, or `tests` destination areas. These checks assume trusted local
project trees; they do not defend against another process actively replacing
parent directories during a command.

The initializer checks Python 3 and the native exclusive rename API before writes,
then completes template copying, metadata, executable setup, and optional Git
initialization in a sibling staging folder. `lib/bootwitch/publish.py` publishes
that folder in one exclusive rename operation. There is no final project copy:
the requested name appears with the complete prepared contents, or publication
fails without creating a partial project there. Existing files, directories, and
symlinks are refused, including destinations created during preparation.

Preparation failures clean owned staging. Publication failures retain the
completed hidden staging folder and print a shell-quoted retry command. Resolve
the reported cause before running that command; a name collision still requires
a different unused destination or resolving the existing path yourself. Never
replace an existing project merely to make a retry succeed. Success leaves no
staging folder. An interruption around the rename can leave either the prepared
stage or the complete destination; inspect both paths if success was not reported.

The helper uses macOS `renamex_np(RENAME_EXCL)` or Linux
`renameat2(RENAME_NOREPLACE)` through Python's standard-library `ctypes`.
It refuses unsupported APIs/filesystems and cross-parent recovery attempts;
it never falls back to ordinary rename or copy. Atomic visibility is not a
power-loss durability guarantee. These semantics assume trusted local parent
directories and filesystems that honor the exclusive rename operation.

The regression suite covers native rename, destination collisions, competing
creators, publication failure and retry, missing capability, and interruption.
CI provisions Python 3 and verified ShellCheck on both macOS and Ubuntu runners.
See the repository's [CI runs](https://github.com/naomijnguyen/bootwitch/actions/workflows/ci.yml)
for the result associated with each commit.

New scripts use a no-clobber write to refuse regular files that arrive during
rendering. A write or permission failure may leave a file requiring inspection;
README refresh runs only after successful creation. Script publication is not an
atomic content swap.

Bundled shell mutation tests run in a disposable project copy and leave the
original project's files and permissions intact. They choose an unused fixture
name and refuse copied trees containing symlinks, to prevent fixture operations
from following links outside the copy. Custom test suites remain responsible for
their own effects.

Tool setup uses the [official ShellCheck release](https://github.com/koalaman/shellcheck/releases/tag/v0.11.0). The previous npm wrapper was removed because its dependency tree included an unpatched archive-extraction advisory. No npm dependencies remain in this toolkit.

Header wording is kept concise while all 13 required fields remain readable by the README builder. See [header design](docs/script-headers.md) for the current example and the tradeoffs in reducing it further.

## License

Bootwitch's source, documentation, and bundled templates are licensed under
[MIT](LICENSE), copyright (c) 2026
[Jennifer Naomi Nguyen](https://github.com/naomijnguyen).

New base and shell projects automatically include the same notice in
`LICENSES/Bootwitch-MIT.txt`. Their README explains how to retain it for copied
Bootwitch code and generated scripts while choosing a license for your own
additions. This notice lives outside the generated README section, so rebuilding
the reference preserves it without expanding component headers.

Previously generated projects are not updated automatically. When maintaining
one, copy `templates/base/LICENSES/Bootwitch-MIT.txt` into its `LICENSES/` folder
and add the licensing explanation from the current template README. Preserve
any existing project license and third-party notices.
