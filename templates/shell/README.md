# {{PROJECT_NAME}}

Created with Bootwitch {{BOOTWITCH_VERSION}} on {{CREATED_DATE}}.

This starter demonstrates wrappers, reusable modules, safe project-relative
paths, generated documentation, progress checkpoints, and optional pause mode.

## Try it

```sh
./wrappers/hello.command
./wrappers/initialize_project.command
./wrappers/run.command
./wrappers/run_with_pauses.command
```

The wrappers are path-aware. This also works from another folder:

```sh
cd /
/path/to/{{PROJECT_NAME}}/wrappers/run.command
```

When run by absolute path or double-clicked in Finder, the workflow still writes
to this project's own `output/` and `logs/` folders.

<!-- BOOTWITCH:DOCS:START -->
Run `./wrappers/initialize_project.command` to generate this section from
`project.header` and the annotated component headers.
<!-- BOOTWITCH:DOCS:END -->

## How script headers become README documentation

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

### Reference format and maintenance

Run `./wrappers/build_readme.command` after adding or changing script headers.
The builder reads `project.header` and marked `@bootwitch:component` /
`@bootwitch:function` comment blocks recursively from `wrappers/`, `modules/`,
`scripts/`, `src/`, and `tests/`. It reads scripts as text without executing them.
New scripts created by `scripts/new-script.sh` include a component header.

Each component header needs Name, Type, Dates, Version, Purpose, Arguments,
Output, Returns, Dependencies, Reads, Writes, Safety, Example, and a closing
`# @bootwitch:end` marker. Keep each field on one line. Supported optional fields
are Display Name, Wrapper, Module, Calls, Created, Last Updated, and How it works.
The renderer supports the complete field set: Name, Type, Dates, Version, Purpose, Arguments, Output, Returns,
Dependencies, Reads, Writes, How it works, Safety, and Example.
Update the starter's Purpose and behavior fields when implementing a script.
Every script header includes a combined Dates line and a separate Version line. Dates use
YYYY-MM-DD. Legacy Created values identify their first tracked/documented date
when original creation is unknown; copying a bundled script preserves its source
history. New custom scripts receive their own creation/update dates when generated.

Version is the individual script revision, separate from the project release.
Existing scripts start at 0.1.0 when this convention is adopted; that baseline does
not reconstruct earlier script versions. New scripts also start at 0.1.0.
On edits, preserve Created, set Last Updated, and bump Version: patch for fixes or
documentation changes, minor for compatible features, major for breaking changes.
README rebuilding displays these values; it does not change dates or versions.

Runnable scripts place `set -e`, `set -u`, and `set -o pipefail` on
separate lines after the header so each safety setting is visible. Bootwitch
does not set `IFS` globally; it uses quoting, arrays, and scoped reads instead.

The README must have exactly one start marker followed by exactly one end marker.
Invalid marker pairs are rejected before the README is changed. Human-authored
text outside a valid pair is preserved.

## Tests

```sh
./tests/run.sh
```

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

### Safe creation and tests

`new-script.sh` rejects symlinked destination areas and refuses existing scripts,
including regular files created while it is rendering. An interrupted or failed
write may leave a partial script: inspect the reported destination before retrying.
The bundled shell tests run in a temporary copy, choose unused fixture names, and
refuse copied trees with symlinks. Your original project is left unchanged by
those bundled mutation tests; custom tests must manage their own effects.
