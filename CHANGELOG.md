# Changelog

## Unreleased

- [2026-09-21] Removed the redundant Homebrew formula version field so strict audit passes while the tag URL remains the version source.

## v0.4.0 - 2026-09-21

### Added

- Added read-only `project-info`, a generated-project module catalog, and an opt-in annotated Python word-count starter available through both project-local and toolkit CLI commands.
- Added a safety-bounded media derivative pilot for images and videos, with source preservation and mandatory human quality review before use.
- Added GitHub-safe export preflight, private staged copies, exact-tree verification, and dry-run-first cleanup for marked failed runs older than 14 days. These tools do not create or publish a public repository.

### Fixed

- Kept documentation wrappers anchored to their generated project and resolved symlinked toolkit entry points.
- Refused colliding export output paths, ignored local environment files in generated projects, and removed Finder metadata from generated-project staging.

### Changed

- The Homebrew formula test now creates a disposable project instead of checking only `help`.

## v0.3.0 - 2026-09-16

- Fixed the Homebrew distribution path with a verified release checksum and the dedicated public `naomijnguyen/homebrew-bootwitch` tap.
- Added the `$HOME/Bootwitch` user workspace convention and idempotent `bootwitch setup`, which prepares `Projects/` and `Documents/` without moving existing content.
- Changed the default destination for `bootwitch init` and `bootwitch summon` to `$HOME/Bootwitch/Projects`, while preserving explicit `--root` and one-time `--workspace` overrides.
- Added a workspace guide and updated CLI help, README, architecture notes, safety documentation, and the reproducible demo to distinguish workspace setup from project initialization.
- Added regression coverage for default path resolution, setup dry runs, idempotent setup, empty workspace rejection, and running commands independently of the current working directory.
- Hardened default path resolution against empty, unset, or non-absolute `HOME` values and added direct file/symbolic-link setup refusal coverage.
- Made formula dry runs preserve the tracked formula and added regression coverage that keeps the GitHub verification workflow read-only.
- Added `bootwitch new-script` as a thin CLI front door to each generated shell project's convention-compliant script template and documentation refresh.
- Added the bounded `make log` release-maintenance helper for changelog and release-note updates.
- Fixed adaptive mount metadata and documented dynamic-source lint handling so generated projects remain `make check` clean.

## v0.2.1 - 2026-09-12

- Generate separate component README and function-level technical readthrough views from shared Bash/Python annotations; refresh both on initialization and script creation.
- Include reusable Python component and language-neutral function header fragments, with marked function notes in the Bash starter.
- Add documentation separation, Python non-execution, and two-output failure/recovery regression coverage without adding Python to generated shell-project runtime.
- Added release workflow `.github/workflows/release-brew-formula.yml` to auto-update `Formula/bootwitch.rb` on `release.published` events (no separate tap required).
- Added Homebrew installation path via hosted formula (`Formula/bootwitch.rb`) for easier end-user install from GitHub, with Linuxbrew compatibility notes.
- Added `tools/bump-brew-formula.sh` to automate formula updates for each release tag.

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
