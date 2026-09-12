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

The Homebrew formula is kept in this repository (no separate tap required), and the
formula is refreshed automatically on each published GitHub release.

For manual distribution verification, run the workflow directly:

```sh
gh workflow run release-brew-formula.yml -f tag_name=v0.2.1 -f dry_run=true
```

Use `dry_run=true` to check the bump path before committing, and `dry_run=false`
to perform the actual release-note + formula update.

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

## Additional documentation

For safety boundaries, publication model, and test-isolation details, see
[Filesystem safety and test isolation](docs/safety-and-test-isolation.md).

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
