# A five-minute Bootwitch demo

Naturally, I did it backwards: I started with the workflow I wanted, then learned
what I needed to make it safer and easier to repeat. This is the shortest path
through that workflow.

Run these commands in Bash from the cloned Bootwitch repository. Project creation
needs Bash 3.2+ and Python 3 on macOS or Linux. Once the shell project exists, it
runs with Bash and standard command-line tools.

## Prepare a disposable Bootwitch workspace

```bash
demo_home=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-demo.XXXXXX")
HOME="$demo_home" bash bin/bootwitch setup --dry-run
HOME="$demo_home" bash bin/bootwitch setup
```

This uses a disposable `HOME` so the demo exercises the real default convention
without writing to your actual home directory. Setup creates only:

```text
$HOME/Bootwitch/
├── Documents/
└── Projects/
```

## Create a disposable project from anywhere

```bash
(cd / && HOME="$demo_home" bash "$OLDPWD/bin/bootwitch" init demo --template shell --no-git)
demo_project="$demo_home/Bootwitch/Projects/demo"
bash "$demo_project/wrappers/hello.command"
```

The subshell changes to `/` before invoking Bootwitch, proving that the current
working directory does not choose the destination. The `Created` line appears
when the project is ready. Then the hello wrapper gives you a quick tour without
changing anything.

## Create a script and see its documentation

```bash
bash bin/bootwitch new-script sample-task scripts --project "$demo_project"
sed -n '1,17p' "$demo_project/scripts/sample-task.sh"
sed -n '/^### `sample-task.sh`$/,/^### /p' "$demo_project/README.md"
```

One of the reasons I started building this was simple: sometimes a script would
run and nothing visible would happen. I wanted it to tell me what it was doing
and whether it had actually finished.

Here, the CLI finds the generated project and uses that project's own script
template. After it creates the file, it refreshes the README and technical
readthrough. The new header records dates, version, arguments, effects, and a
runnable example. Open the README in a Markdown viewer to see the full component
reference, then open `docs/technical-readthrough.md` for the function-level view.

## Run the workflow and tests

```bash
bash "$demo_project/scripts/sample-task.sh"
bash "$demo_project/wrappers/run.command"
bash "$demo_project/tests/run.sh"
bash "$demo_project/tests/run.sh"
```

The sample script prints a status message and writes to the project log. Running
the tests twice is a quick way to check that the same project still behaves the
same way on another pass. Any mutation checks happen in disposable copies, not
in the sample script you just created.

## Run it again and let it say no

```bash
cp "$demo_project/README.md" "$demo_home/readme-before.md"
bash "$demo_project/wrappers/build_readme.command"
cmp "$demo_home/readme-before.md" "$demo_project/README.md"
bash bin/bootwitch new-script sample-task scripts --project "$demo_project"
```

`cmp` stays quiet when the rebuilt README is unchanged. The final command asks
Bootwitch to create `sample-task.sh` a second time, and Bootwitch says no. That is
the useful result: creating a new file should not quietly replace something you
may have already changed.

The demo workspace stays at the path created by `mktemp`, so you can keep looking
through it afterward.

## Check Bootwitch itself

```bash
make setup
make check
```

Setup downloads a pinned local ShellCheck binary and checks its checksum before
using it. The full check covers syntax, lint, generated projects, documentation,
filesystem behavior, publication, and tool setup. Nothing is installed globally.

## Keep exploring

At this point, you have created a project, added a script from a shared convention,
rebuilt two kinds of documentation from source comments, and run the project's
checks. If you want to see how the pieces connect, compare the generated script
with `README.md`, `docs/technical-readthrough.md`, and
`.bootwitch/templates/script.sh.tpl`.

Generated projects keep their own templates, so a later Bootwitch update does not
quietly rewrite an older project's starting point. Use trusted local project
folders when trying the wrappers; they are real scripts running on your machine.

## Prefer clicking?

On macOS, open the generated project's `wrappers` folder in Finder and
double-click `hello.command`. It should open Terminal and show the greeting.
If macOS file associations or quarantine settings get in the way, the Terminal
commands above work on both supported platforms.
