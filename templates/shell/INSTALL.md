# Installation

This project uses portable Bash and requires Bash 3.2 or newer. No privileged
installation is performed automatically.

Run it directly:

```sh
./wrappers/initialize_project.command
./wrappers/run.command
./wrappers/run_with_pauses.command
```

Create each new project script from the canonical annotated template:

```sh
./scripts/new-script.sh backup-data
./scripts/new-script.sh parse-results src
./scripts/new-script.sh test-parser tests
```

The destination defaults to `scripts` and may be `scripts`, `src`, or `tests`.
The generator refuses to overwrite an existing path.

The generator refreshes both the README component reference and
`docs/technical-readthrough.md`. After direct source edits, rebuild both with:

```sh
bash wrappers/build_readme.command
```

Python files can use the bundled component-header fragment; marked Python
comments are discovered as text. The generated shell project and documentation
builder still run without Python unless your own code requires it.
