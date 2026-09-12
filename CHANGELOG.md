# Changelog

## Unreleased
- Added Homebrew installation path via hosted formula (`Formula/bootwitch.rb`) for easier end-user install from GitHub, with Linuxbrew compatibility notes.

## v0.2.0 - 2026-09-12

- Prepare sharing: align explicit Bash settings, enforce universal headers, shorten starter-header prose, update and pin CI actions, and document the reproducible demo and header tradeoffs.
- Require pinned, checksum-verified local ShellCheck in make check and CI; remove the npm wrapper dependency tree, fix lint findings, and test safe tool archive handling.
- Replace final project copying with native atomic exclusive rename; require Python 3 for toolkit creation, retain completed staging and print a retry command on publication failure. Add collision, recovery, dependency, and interruption regressions.
- Fix reviewed filesystem bugs: isolate generated mutation tests, reject unsafe template/script paths, propagate executable setup failures, and reserve project/script destinations against late collisions. Add RF-001–RF-005 regressions.
- Validate script annotations and required metadata before atomic README publication; clean up failed builds and preserve README permissions.
- Use deterministic file discovery and compact Dates headers while accepting legacy date fields.

- Automatically refresh the README after script creation; retain the script and report status 3 with a retry command if refresh fails.

- Standardized active script, module, wrapper, and test component headers.
- Added per-script Created, Last Updated, and Version metadata to headers and README rendering.
- Preserved qualified legacy origin dates and initialized per-script versions at 0.1.0.
- New custom scripts receive their own creation/update dates and an accurate destination example.
- README discovery includes nested scripts and tests, with strict marker-pair validation.

## v0.2.0-dev - 2026-09-09

- Standardized one README-readable component header across scripts, modules,
  wrappers, tests, and the new-script template; added complete-header coverage.
- Expanded the three Bash safety settings for teaching and removed global
  `IFS` overrides in favor of quoting, arrays, and scoped reads.
- Adopted pre-public semantic versioning for the current Bootwitch line.
- Added project-local ShellCheck through npm and wired it into `make check`.
- Added public README and architecture documentation updates.
- Moved private curation, source-history, portfolio assessment, and working-memory notes outside the public-facing scaffold folder.
- Verified a temporary `hello-bootwitch` generated project end to end.

## v0.1.0 - 2026-09-03

- Rebuilt Bootwitch as a portable, non-destructive project scaffolder.
- Added `base` and `shell` templates.
- Added safe project metadata, dry-run support, diagnostics, and tests.
- Documented the origin inventory and migration boundaries.
- Added a canonical annotated shell-script template and safe project-local
  generator.
- Expanded function comments to explain arguments, output, control flow, and
  safety behavior for learners.
- Expanded the shell starter into a working mini project with wrappers, modules,
  root discovery, runtime folders, generated README documentation, and optional
  checkpoint pauses.
