# Bootwitch workspace guide

Bootwitch separates one user-owned workspace from the individual projects it
creates. The toolkit installation, workspace, and projects are related, but they
are not the same directory.

## The three locations

```text
Bootwitch installation
  Contains bin/, lib/, and templates/ used by the command.

$HOME/Bootwitch
  The current user's Bootwitch workspace.

$HOME/Bootwitch/Projects/<project-name>
  One independent generated project.
```

The CLI calls its installation directory `BOOTWITCH_HOME`. That name does not
refer to `$HOME/Bootwitch`.

## Set up the workspace once

Preview the operation first when useful:

```bash
bootwitch setup --dry-run
```

Then prepare the workspace:

```bash
bootwitch setup
```

The command idempotently ensures this minimal structure exists:

```text
$HOME/Bootwitch/
├── Documents/
└── Projects/
```

Running setup again preserves existing contents. Setup does not clone, move,
rename, adopt, or modify existing projects.

## Create projects from anywhere

After Bootwitch is installed, the current working directory does not control the
default destination. Each of these invocations creates the same destination:

```bash
cd "$HOME"
bootwitch init example --template shell

cd /tmp
bootwitch init example --template shell
```

The second command refuses because the first already created:

```text
$HOME/Bootwitch/Projects/example
```

Bootwitch never merges into or overwrites an existing destination.

## Choose another path explicitly

Use a one-time workspace target for setup:

```bash
bootwitch setup --workspace "$HOME/AnotherWorkspace"
```

That option prepares `AnotherWorkspace/Projects` and
`AnotherWorkspace/Documents`; it does not persistently change later defaults.

Use `--root` when one project should be created somewhere else:

```bash
bootwitch init experiment --root "$HOME/Desktop" --template shell
```

That creates `$HOME/Desktop/experiment`.

## New projects and existing repositories

`bootwitch init` is for new projects. It creates a fresh project structure,
optional local Git repository, starter documentation, and project-local tooling.

An existing repository should not be placed inside a newly generated scaffold
or modified merely to resemble one. Move or clone existing repositories through
a separate, reviewed migration process. Bootwitch does not currently provide an
`adopt` command.

Future small projects are good candidates for `bootwitch init` because they
receive the annotated scripts and generated documentation from the beginning.
Existing projects can retain their own architecture until an explicit adoption
workflow exists.

## Inspect the active defaults

```bash
bootwitch doctor
```

The report shows the current user's workspace and default project root along
with the required and optional local tools.
