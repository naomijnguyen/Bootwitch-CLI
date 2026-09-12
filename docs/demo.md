# A five-minute Bootwitch demo

Run these commands in Bash from the cloned Bootwitch repository. Project creation
requires Bash 3.2+, Python 3, and native exclusive rename support on macOS or Linux.
The generated shell project itself runs with Bash and standard command-line tools.

## Create a disposable project

```bash
demo_root=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-demo.XXXXXX")
bash bin/bootwitch init demo --template shell --root "$demo_root" --no-git
demo_project="$demo_root/demo"
bash "$demo_project/wrappers/hello.command"
```

The creation command prints a `Created` line only after publication succeeds.
The greeting introduces the generated project without changing it.

## Create a script and see its documentation

```bash
bash bin/bootwitch new-script sample-task scripts --project "$demo_project"
sed -n '1,17p' "$demo_project/scripts/sample-task.sh"
sed -n '/^### `sample-task.sh`$/,/^### /p' "$demo_project/README.md"
```

The CLI finds the generated project and delegates to that project's canonical
template. The generator prints the script path and both updated documentation
paths. Its populated
header includes creation/update dates, version, arguments, effects, and a runnable
example. Open README.md in a Markdown viewer to inspect the complete reference.

## Run the workflow and tests

```bash
bash "$demo_project/scripts/sample-task.sh"
bash "$demo_project/wrappers/run.command"
bash "$demo_project/tests/run.sh"
bash "$demo_project/tests/run.sh"
```

Both test runs should succeed to show repeatability. The bundled mutation tests work
in disposable copies; they do not replace the original project's sample script.

## Show repeatability and refusal

```bash
cp "$demo_project/README.md" "$demo_root/readme-before.md"
bash "$demo_project/wrappers/build_readme.command"
cmp "$demo_root/readme-before.md" "$demo_project/README.md"
bash bin/bootwitch new-script sample-task scripts --project "$demo_project"
```

`cmp` should report no difference and return 0. The final command is an intentional
failure: it refuses the existing script. Do not show that refusal as a failed demo.
The demo directory is retained at the path printed by the initializer.

## Verify the toolkit

```bash
make setup
make check
```

Setup explicitly downloads a pinned, checksum-verified local ShellCheck binary.
The checks run syntax, lint, generated-project, documentation, filesystem,
publication, and tool-setup tests. No dependencies are installed globally.

## What the demo proves—and its limits

This demonstrates scaffolding, text-based documentation, repeatable tests, and
safe refusal of an existing destination. Fault-injection tests cover additional
failure paths. It is a developer-tooling portfolio demonstration, not a claim of
power-loss durability or resistance to another process replacing parent paths.
Use trusted local project folders. Old generated projects need deliberate updates
to receive newer templates. A generated-script write failure can leave a partial
script; project-directory publication uses a separate atomic operation.

## macOS Finder entry point

In Finder, open the generated project's `wrappers` folder and double-click
`hello.command`. It should open Terminal and show the greeting. This workflow
depends on local macOS file associations and download/quarantine policy; the
Terminal commands above are the reproducible path on both platforms.
