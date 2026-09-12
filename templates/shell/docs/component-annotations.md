# Source annotations and generated documentation

Keep two kinds of source comments for two audiences:

- Component headers describe how to use a script or component. They feed the README reference.
- Inline function annotations explain implementation. They feed `docs/technical-readthrough.md`, grouped by source file.

Both documents are generated from the same source files. The builder reads
comments as text; it never imports Python or executes the documented scripts.

## Component header

Place `# @bootwitch:component` immediately after the shebang and close the block
with `# @bootwitch:end`. Include all 13 fields on separate, single lines:

`Name`, `Type`, `Dates`, `Version`, `Purpose`, `Arguments`, `Output`, `Returns`,
`Dependencies`, `Reads`, `Writes`, `Safety`, and `Example`.

The Bash generator supplies a complete starter header. For Python source, use
`.bootwitch/templates/python-component.header.tpl` as a reusable header fragment
and replace every placeholder. Put Python module docstrings after the header.
The project-local new-script command continues to generate Bash, not Python.
Python documentation discovery does not add a Python runtime dependency to the
shell starter or its documentation builder.

Use language-accurate descriptions. CLI return codes are different from a Python
function's returned value or exceptions. A function that returns a dictionary
should not claim that it writes a report. Describe optional writes and conditional
dependencies explicitly. Safety fields must describe implemented boundaries.

The renderer also supports `Display Name`, `Wrapper`, `Module`, `Calls`, and
`How it works`. Legacy separate `Created` and `Last Updated` remain readable;
prefer combined `Dates` in new headers. Unknown fields are not exported.

## Inline function annotation

The shared `.bootwitch/templates/function-annotation.tpl` fragment works with
both Bash and Python. Place it immediately above the function definition and fill
in `Name`, `Purpose`, `Arguments`, `Output`, `Returns`, `Reads`, `Writes`, and
`Safety`. Keep comment markers at column zero.

The Bash starter already includes marked blocks for root discovery and its main
workflow. Update these descriptions as behavior changes. Ordinary comments and
Python docstrings remain useful for local explanations, but only marked function
blocks appear in the technical readthrough.

## Refresh both documents

From the generated project root:

```sh
bash wrappers/build_readme.command
```

Initialization and new-script creation call this same build path. Direct source
edits need an explicit rebuild. Running a generated script does not refresh docs.

The builder discovers `.sh`, `.command`, and `.py` files recursively in `wrappers/`,
`modules/`, `scripts/`, `src/`, and `tests/`, skipping symlinks. It renders both views
before publishing either, preserves authored README text outside its markers,
and replaces the wholly generated technical readthrough.

Each file replacement is atomic, but the two replacements are not one transaction.
If the readthrough publishes and the README replacement fails, the error explains
that partial update. Rerun the builder to refresh both. Avoid concurrent edits to
source and documentation during a build. Existing generated projects receive
these helpers only through deliberate migration; creating a new project does not
change older projects.

## Adaptive mounts and parser loading

Documentation entry points use a three-step contract:

1. Mount discovery finds the nearest `.bootwitch/project.conf` from the current
   location.
2. Language detection classifies the project from source structure and file markers.
3. The matching documentation provider is selected only after language is known.

This order keeps wrapper behavior portable and avoids loading parsers before
finding the project. The shell template currently selects the shell documentation
module by default while still scanning Python files as text. Future language
providers can be added without changing wrapper command surfaces.
