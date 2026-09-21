# Shell module catalog

`modules/manifest.psv` is the generated project's human-readable index of
its bundled shell modules. Each non-comment row has three pipe-separated
fields: module name, short purpose, and comma-separated exported function
names. The ten rows describe the modules shipped with the shell template;
they are not commands to execute or packages to install.

Source the finder with a selected `PROJECT_ROOT`, then ask what is available:

```bash
. "$PROJECT_ROOT/modules/module_finder.sh"
project_list_modules
project_find_module_for project_make_executable
project_find_module permissions
```

The list prints module names and purposes. Both lookup functions print a
path, not a module body, and never source it. `project_find_module_for` uses
the local manifest only; the older `project_find_module NAME` still prefers
a local regular file and may fall back to the explicitly configured
`BOOTWITCH_SHARED_MODULES` directory. A manifest row is descriptive, not
permission to load shared code. If you add or rename a bundled module,
update its row and exported functions together; Bootwitch's template tests
check that every listed function is actually declared and every bundled
module is listed.

This catalog covers generated-project Bash modules, not Bootwitch's toolkit
Python utilities or the portfolio content-pack manifest. Those have
different runtimes and trust boundaries.
