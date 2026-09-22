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

Try the opt-in Python word-count starter (Bash remains the default):

```sh
bash wrappers/new_script.command word-demo scripts --language python
python3 scripts/word-demo.py --help
python3 scripts/word-demo.py --text "Bash bash Python" --top 2
```

The script uses `argparse` and `collections.Counter` from Python's standard
library. Its inline annotations feed this project's README and technical
readthrough; it does not install packages, read files, or use the network.
See [the Python starter guide](docs/python-starter.md) for the function,
import, loop, and command-line examples.

The wrappers are path-aware. This also works from another folder:

```sh
cd /
/path/to/{{PROJECT_NAME}}/wrappers/run.command
```

The documentation wrappers resolve the project adaptively. `build_readme.command` and
`initialize_project.command` first locate the nearest Bootwitch project root, then detect
the source language, then load the matching documentation provider. For now, shell providers
power the project docs, and Python sources are parsed as static annotations only.

When run by absolute path or double-clicked in Finder, the workflow still writes
to this project's own `output/` and `logs/` folders.

<!-- BOOTWITCH:DOCS:START -->
Run `./wrappers/initialize_project.command` to generate this section from
`project.header` and the annotated component headers.
<!-- BOOTWITCH:DOCS:END -->

## Generated documentation

Keep component usage and implementation detail in two readable views:

- The README reference uses `@bootwitch:component` headers for purpose, invocation, dependencies, output, and safety boundaries.
- `docs/technical-readthrough.md` uses `@bootwitch:function` annotations, grouped by source file with links to the code.

The shared builder discovers annotated `.sh`, `.command`, and `.py` files. It
reads comments as text without executing shell scripts or importing Python.
Python discovery does not require Python in generated shell-project runtime.

From the root of a generated shell project:

```sh
bash scripts/new-script.sh sample-task scripts
# After later edits to component or function annotations:
bash wrappers/build_readme.command
```

Script creation and project initialization refresh both views automatically.
Direct source edits need the explicit build command. Running a script does not
rebuild documentation. Keep the descriptions beside the code and update them
when behavior changes; the renderer cannot infer behavior from implementation.

Both component and function templates are included. Bash generation uses the
annotated shell starter; Python files can use the reusable component-header
fragment. The new-script command remains Bash-only. Every component keeps the
13-field header, with actual creation/update dates and a component version.
Function blocks describe inputs, outputs, returns, reads, writes, and safety.
Keep every field on one line. Ordinary comments and Python docstrings are not
exported; legacy date fields remain readable.

The README must contain exactly one ordered pair of Bootwitch documentation
markers. Authored text outside those markers is preserved. The technical
readthrough is wholly generated, so edit its source annotations rather than the
output file. Rendering validates both views before publication. Each file is
replaced atomically; the pair is not a single transaction. If README publication
fails after the readthrough updates, rerun the builder to bring both up to date.

If script creation succeeds but documentation refresh fails, the generator keeps
the new script, reports status 3, and prints a builder retry command. Do not
recreate the script. Existing generated projects need deliberate migration to
receive newer template helpers.

See [the annotation guide](docs/component-annotations.md) for the template fields and refresh rules.
See [adaptive mount behavior](docs/adaptive-mounts.md) for root discovery and language-aware provider selection.

## Tests

```sh
./tests/run.sh
```

### Reliable documentation builds

The builder validates marked blocks and requires nonempty names, balanced markers,
and unique fields. Project purpose, type, version, status, and primary wrapper
must also be populated. Files are discovered in stable order.

Both views are rendered before publication. Validation or rendering failure leaves
both existing documents unchanged. Each replacement preserves the existing file's
permission mode and staging is cleaned on ordinary failure or catchable signals.
The two replacements are sequential; a late README publication failure can leave
the new readthrough with the old README and is reported explicitly. Rerun the
builder to refresh both. Symlink documentation destinations are rejected.

### Safe creation and tests

`new-script.sh` rejects symlinked destination areas and refuses existing scripts,
including regular files created while it is rendering. An interrupted or failed
write may leave a partial script: inspect the reported destination before retrying.
The bundled shell tests run in a temporary copy, choose unused fixture names, and
refuse copied trees with symlinks. Your original project is left unchanged by
those bundled mutation tests; custom tests must manage their own effects.

## License

Bootwitch author: [Jennifer Naomi Nguyen](https://github.com/naomijnguyen).

The starter code and documentation supplied by Bootwitch are covered by the
[Bootwitch MIT license](LICENSES/Bootwitch-MIT.txt), including the bundled script
template. Preserve that notice when redistributing copies or substantial portions
of Bootwitch code, including scripts made from the template. If distributing a
script separately, include the notice with it.

Choose a license for your own additions separately; generating this project does
not assign your code to Bootwitch's author or choose your project's overall
license. Keep Bootwitch's notice alongside any license you add.
