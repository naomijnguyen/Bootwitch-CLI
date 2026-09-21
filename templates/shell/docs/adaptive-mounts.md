# Adaptive mounts and documentation providers

Bootwitch shell project docs are now resolved through a simple flow:

1. Discover the nearest project root by walking upward to find `.bootwitch/project.conf`.
2. Detect language from project markers and file types.
3. Load the documentation module that matches the detected language.

This keeps wrappers anchored to their own project regardless of the terminal's
working directory and avoids loading a language parser too early.

The shared `project_mount_select_context WRAPPER_PATH [PROJECT_PATH]` function in
`modules/adaptive_mounts.sh` performs all three steps for both documentation
wrappers and sets `PROJECT_ROOT`, `PROJECT_LANGUAGE`, and
`PROJECT_DOCUMENTATION_MODULE`. It reuses `project_find_root` from
`modules/project_root.sh` for the upward walk. The toolkit-level
`bootwitch new-script` root lookup remains separate because it validates an
explicit project path and rejects symlinked marker components.

## Discovery behavior

- Root discovery starts at the wrapper location by default. The caller's
  working directory never silently selects another project.
- Use `--project PATH` on either documentation wrapper to intentionally select
  another marked project. An invalid explicit path fails; it does not fall back.
- If no marker is found, docs wrappers fail with a clear message.
- A valid root requires `.bootwitch/project.conf`.

## Language detection behavior

- Strong file markers are checked first (`src/main.py`, `scripts/main.sh`, etc.).
- If no marker exists, file-type scanning checks `src`, `scripts`, and `tests`.
- Unknown or mixed roots default safely to the shell provider today.

## Why this order

1. Keep project selection explicit before parsing.
2. Keep parse providers pluggable for future language support.
3. Keep generated shell runtime unchanged while allowing richer providers later.

The generated shell template currently reads annotations from `.sh`, `.command`, and `.py`
as plain text and does not import Python modules during docs builds.
