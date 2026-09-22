# Template authoring

Bootwitch composes templates in two layers. Every project receives
`templates/base`; a selected specialized template is copied over it.

## Rules

- Template names are lowercase directory names under `templates/`.
- A specialized template may add or deliberately replace base files.
- Use `{{PROJECT_NAME}}`, `{{CREATED_DATE}}`, and `{{BOOTWITCH_VERSION}}` for
  supported substitutions.
- Keep generated paths relative to the project root.
- Keep `templates/shell/modules/manifest.psv` aligned with the bundled shell
  modules and their exported functions. The generated project's
  `docs/module-catalog.md` explains its lookup-only interface; catalog
  entries never authorize automatic sourcing or installation.
- Do not include credentials, usernames, cloud locations, `sudo`, background
  services, or destructive cleanup commands.
- Generated shell code must remain within the Bash 3.2 feature set.
- Put runnable shell entry points in `scripts/`, `src/`, or `tests/`; Bootwitch
  marks shell files in those directories executable.

## Adding a template

1. Create `templates/<name>` containing only additions or overrides to base.
2. Add the name and description to `bootwitch_list`.
3. Add integration coverage that generates and runs the template in a temporary
   directory.
4. Run `make check` on macOS and the CI matrix before release.

Generated project metadata is written separately to `.bootwitch/project.conf`.
Consumers must use the allowlisted parser in `lib/bootwitch/config.sh`; never
source metadata as shell code. The parser validates exactly the five fields
written by the current schema before returning a requested value; duplicate,
unknown, missing, or malformed fields fail. The read-only `bootwitch
project-info [--project PATH]` command is the supported way to inspect a
generated project's record from the toolkit.

Every template inherits `docs/project/`, a version-controlled memory folder for
current state, decisions, questions, and dated work-session updates. Specialized
templates may add relevant starting context, but should preserve the common
headings in `updates/update-template.md` so people and coding assistants can
scan every project consistently.

## Shell script format

Shell projects include `.bootwitch/templates/script.sh.tpl` and the safe
`scripts/new-script.sh` generator. Create new scripts through the generator so
they share the same metadata header, strict mode, path resolution, `main` entry
point, logging helper, and instructional annotation format.

The same project-local generator can opt into the complete
`.bootwitch/templates/script.py.tpl` starter with `--language python`. Bash
remains the default. The Python example uses only the standard library and
must not silently add packages to a generated shell project. The separate
`python-component.header.tpl` remains a fragment for custom Python modules.

The toolkit-level `bootwitch new-script` command is a thin front door to this
project-local generator. It may locate the nearest generated project or accept
`--project PATH`, but it must not render from the toolkit's current template
directly into an older project. This preserves independently versioned projects
and gives local CLI tests the same behavior as the generated wrapper. The
toolkit front door forwards `--language python` to projects whose own generator
supports it; older generated projects are not silently upgraded.

Document functions with the headings that help a reader predict behavior:
`Function`, `Purpose`, `Arguments`, `Output`, `Returns`, `How it works`, and
`Safety`. Include only useful headings; small helpers do not need empty sections.

## Script header maintenance

All active Bash scripts, sourced modules, wrappers, tests, and the future-script
`.tpl` start with a marked component header immediately below the shebang.
The universal required fields are Name, Type, Dates, Version, Purpose, Arguments,
Output, Returns, Dependencies, Reads, Writes, Safety, and Example. Relationship
fields such as Display Name, Wrapper, Module, and Calls remain optional. For
modules, distinguish loading the file from calling its functions. Keep every
field on one line for the README renderer. Prefer short, concrete descriptions;
retain effect and failure details. See [header design](script-headers.md).

```bash
#!/usr/bin/env bash
# @bootwitch:component
# Name: scripts/example.sh
# Type: script
# Dates: Created: YYYY-MM-DD | Last Updated: YYYY-MM-DD
# Version: 0.1.0
# Purpose: Describe the script's one job.
# Arguments: Describe accepted arguments, or None.
# Output: Describe stdout, stderr, and created files.
# Returns: Describe success and intentional failure statuses.
# Dependencies: List runtime commands and project modules.
# Reads: List files, configuration, or external state read.
# Writes: List files or state changed, or None.
# Safety: State the boundaries that prevent unintended changes.
# Example: bash scripts/example.sh
# @bootwitch:end
```

Runnable scripts put the three Bash safety settings immediately after the header.
They are written separately so learners can recognize each guardrail. Do not set
`IFS` globally; quoted expansions, arrays, and command-scoped `IFS=` reads
preserve argument boundaries without changing splitting behavior everywhere.

```bash
set -e
set -u
set -o pipefail
```

Dates (containing Created and Last Updated) and Version are required. Use YYYY-MM-DD dates; mark a
legacy first-tracked or first-documented date explicitly when original creation
is unknown. Preserve that source history when a bundled script is copied into a
new project. New custom scripts use SCRIPT_CREATED_DATE and SCRIPT_UPDATED_DATE
placeholders filled by new-script.sh, independently of project creation.

Per-script versions start at 0.1.0 with this convention. Preserve Created on edits,
update Last Updated, and bump the patch for fixes/documentation, minor for compatible
features, or major for breaking changes. The toolkit VERSION and project.header
remain project release metadata. README builds only read script metadata.

New-script creation automatically invokes `wrappers/build_readme.command` after
publishing the executable. The direct generator and its clickable wrapper share
this behavior. Status 3 means creation succeeded but documentation failed: keep
the script, fix the reported problem, and run the printed README retry command.
Existing-destination refusal happens before any README rebuild. Editing existing
headers still requires a manual rebuild; running a script does not refresh docs.

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

## License notices

The base layer includes `LICENSES/Bootwitch-MIT.txt`, an exact copy of the toolkit
MIT license. Preserve it in overlays that reuse Bootwitch content. If an overlay
replaces README.md, retain the licensing explanation outside generated markers.
Keep notices for any additional third-party material alongside their code.
