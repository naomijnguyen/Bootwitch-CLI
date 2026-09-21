# Adaptive mounts and documentation providers

Bootwitch shell project docs are now resolved through a simple flow:

1. Discover the nearest project root by walking upward to find `.bootwitch/project.conf`.
2. Detect language from project markers and file types.
3. Load the documentation module that matches the detected language.

This keeps wrappers portable when called from different working directories and
avoids loading a language parser too early.

The shared `project_mount_select_context CALLER_PATH WRAPPER_PATH` function in
`modules/adaptive_mounts.sh` performs all three steps for both documentation
wrappers and sets `PROJECT_ROOT`, `PROJECT_LANGUAGE`, and
`PROJECT_DOCUMENTATION_MODULE`. It reuses `project_find_root` from
`modules/project_root.sh` for the upward walk. The toolkit-level
`bootwitch new-script` root lookup remains separate because it validates an
explicit project path and rejects symlinked marker components.

## Discovery behavior

- Root discovery starts at the caller location first, then falls back to the wrapper location.
- Consequently, running a documentation wrapper from *inside another marked
  project* selects that caller project. Use a neutral working directory when
  you intend to act on the project containing the wrapper.
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
