# Bootwitch Architecture

Current version: `v0.2.0-dev`

Bootwitch is a local scaffolding tool. Its job is to create predictable project
workspaces without taking ownership of the user's machine, cloud accounts, or
background services.

The casual version: Bootwitch is a careful project starter. It builds the
folder, puts the helpful scripts where you expect them, writes down what it did,
and avoids surprising actions like overwriting an existing project or depending
on a private path on one laptop.

## Goals

- Generate small, understandable project foundations.
- Keep generated projects portable across folders and machines.
- Make shell workflows easier to run through friendly wrappers.
- Keep reusable behavior in annotated modules.
- Use conservative filesystem behavior: validate first, stage writes, then
  publish the completed project.
- Produce documentation that matches the generated files.

## Non-goals

- No privileged installer.
- No daemon, login item, or background service.
- No cloud synchronization or remote publishing.
- No remote Git setup, authentication, or automatic commits.
- No large application framework templates until the core scaffolder is stable.

## Runtime Shape

```text
bin/bootwitch
    -> resolves BOOTWITCH_HOME from its own location
    -> loads lib/bootwitch/core.sh
    -> calls bootwitch_main "$@"

lib/bootwitch/core.sh
    -> command dispatch
    -> project-name validation
    -> template lookup
    -> staged project generation
    -> token replacement
    -> executable-bit setup
    -> local Git initialization
    -> environment diagnostics

lib/bootwitch/config.sh
    -> allowlisted plain-text metadata reader

templates/base/
    -> language-neutral project foundation

templates/shell/
    -> Bash-oriented overlay with wrappers, modules, tests, logs, output, and
       documentation generation
```

## Command Dispatch

`bin/bootwitch` is intentionally thin. It calculates `BOOTWITCH_HOME` from the
installed executable path and sources the core library from that trusted
location. The CLI then dispatches only known command names:

- `init`
- `summon`
- `list`
- `templates`
- `wizard`
- `doctor`
- `help`

Unknown commands fail closed. Bootwitch does not use dynamic shell evaluation
to turn user input into code.

## Project Generation Flow

`bootwitch init NAME` creates a project through a staged generation pipeline.

1. Parse only supported options: `--template`, `--root`, `--no-git`, and
   `--dry-run`.
2. Validate the project name as one safe directory segment.
3. Confirm the requested template exists under the Bootwitch installation.
4. Expand only `~` and `~/...` in the project root path.
5. Refuse to continue if the final destination already exists.
6. In dry-run mode, print the planned destination and exit before writing.
7. Check Python 3 and exclusive rename API availability, then create a unique staging directory beside the final destination.
8. Copy the `base` template, then overlay the selected specialized template.
9. Write `.bootwitch/project.conf` as plain text metadata.
10. Replace template tokens in staged files.
11. Mark generated shell scripts and `.command` wrappers executable.
12. Optionally initialize a local Git repository with `main` as the branch.
13. Exclusively rename the completed staged project into its final destination.

Preparation failures clean the owned temporary directory. Publication uses the
native exclusive rename helper: failures retain the completed stage for recovery;
success makes the complete project visible without a second copy.

## Template Overlay Model

Templates are copied from trusted directories inside the Bootwitch repository.
The `base` template provides the common project foundation. Specialized
templates layer additional files on top.

Today the supported templates are:

- `base`: README, changelog, editor settings, Git ignore file, metadata folder,
  and a tiny test harness.
- `shell`: Bash workflow starter with wrappers, modules, source script,
  generated documentation hooks, logs, output, cache, temp, and tests.

The overlay model keeps the starter small while leaving room for future
templates to share a foundation.

## Metadata Model

Generated projects receive `.bootwitch/project.conf` with fields such as:

```text
BOOTWITCH_SCHEMA=1
PROJECT_NAME=my-project
TEMPLATE=shell
CREATED_DATE=2026-09-08
BOOTWITCH_VERSION=0.2.0-dev
```

This file is data, not executable configuration. `lib/bootwitch/config.sh`
reads only allowlisted keys and never sources the file. That keeps project
metadata useful without letting arbitrary text become shell code.

## Wrapper And Module Pattern

The shell template separates friendly entry points from reusable behavior.

Wrappers live in `wrappers/`. They are short `.command` files meant to be
obvious and clickable on macOS while still runnable from a terminal.

Modules live in `modules/`. They hold the reusable implementation for:

- finding the project root;
- deriving project-relative paths;
- writing logs;
- printing checkpoints;
- detecting the platform;
- parsing annotated headers;
- generating README documentation;
- validating executable-permission changes.

This is a separation-of-concerns choice. A wrapper should answer "what do I
run?" A module should answer "how does that behavior work?"

## Path Strategy

Generated shell projects avoid assuming the user launches scripts from a
particular directory. Runtime scripts discover the project root by walking up
from the script's actual location until they find `.bootwitch/project.conf`.

After discovery, modules derive operational paths from `PROJECT_ROOT`, such as
logs, output, cache, and temporary folders. This makes scripts more portable and
lets a moved script continue working from deeper inside the same project.

## Documentation Strategy

Bootwitch uses two documentation layers:

- The public README explains the project for visitors.
- `docs/project/` preserves working memory: current state, decisions, open
  questions, and dated updates.

Generated shell projects also include annotated component headers. The
documentation module can read those headers and update a marked section of the
generated README. The principle is that documentation should be generated from
current scaffold facts when possible, then reviewed in plain language.

## Safety Boundaries

Bootwitch's current safety model is local and filesystem-focused:

- validate project names before creating files;
- reject path traversal and unsafe name characters;
- refuse existing destinations;
- support `--dry-run`;
- stage generated files before final publication;
- clean only owned incomplete staging; retain completed staging on publication failure;
- treat metadata as plain text;
- source libraries only from the resolved Bootwitch installation or generated
  project root;
- do not install dependencies, escalate privileges, configure services, or
  contact cloud providers.

## Testing

The test suite is shell-based and runs through `make check`.

Current coverage includes:

- CLI template listing;
- dry-run behavior;
- invalid project-name rejection;
- roots with spaces;
- base and shell project generation;
- metadata creation;
- optional Git initialization;
- generated project test execution;
- overwrite protection.

ShellCheck is required for `make check`, using the pinned official binary under
`.tools/bin/`. `make setup` verifies a committed archive checksum and extracts only
the expected regular binary member. Python standard-library tooling replaces the
npm wrapper and its archive dependency tree. CI runs this explicit setup on both
configured platforms. shfmt and Bats remain optional; generated shell projects
have no lint-tool runtime dependency.

## Portfolio Notes

For job-application or portfolio use, Bootwitch should be framed as practical
developer tooling rather than a large application platform. The most relevant
technical terms are:

- CLI design;
- project scaffolding;
- template rendering;
- defensive shell scripting;
- command dispatch;
- staged filesystem writes;
- portability;
- local metadata;
- wrapper/module architecture;
- observability through logs and checkpoints;
- integration testing;
- AI-assisted development workflow.

The strongest story is not "I wrote every line by hand." The stronger and more
truthful story is: "I directed an AI-assisted tooling project, reviewed the
implementation, learned the technical concepts behind it, and can explain the
architecture, tradeoffs, and safety boundaries."

## Build-Out Direction

Bootwitch is worth building further, but the next stage should strengthen the
small tool rather than inflate it into an everything-platform.

The highest-value next steps are:

- keep a permanent generated `hello-bootwitch` demo project;
- finalize the `config/`, `data/`, `logs/`, `cache/`, `temp/`, and `output/`
  layout;
- add a template manifest or template-verification command;
- complete a privacy and secret scan before publication;
- choose a license and public Git identity;
- publish a short demo walkthrough;
- add new templates only after the base and shell templates remain stable.

## Atomic project publication

The active initializer uses `lib/bootwitch/publish.py`, a Python 3 standard-library
helper around native exclusive rename. Python/API preflight runs before writes.
After all preparation succeeds, the complete sibling staging directory is renamed
without replacing an existing path. The earlier reservation-and-copy approach is
superseded; there is no final copy or user-visible partially copied project.

Preparation failures clean their staging. Once publication begins, the completed
stage is retained on failure with a retry command. An interruption can leave the
stage or the complete destination, so recovery inspects both; it never blindly
removes the destination. Unsupported APIs/filesystems fail closed. This guarantees
atomic namespace publication on supported local filesystems, not power-loss
persistence or protection against hostile replacement of parent directories.
