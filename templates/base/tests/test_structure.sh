#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_structure.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Verify required project paths and metadata schema.
# Arguments: None.
# Output: Silent on success; missing-path errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, grep.
# Reads: Required project directories, documentation, and .bootwitch/project.conf.
# Writes: None.
# Safety: Checks existence and schema text without evaluating project metadata.
# Example: bash tests/test_structure.sh
# @bootwitch:end

set -euo pipefail
IFS=$'\n\t'

PROJECT_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

for required_path in \
  README.md \
  CHANGELOG.md \
  docs \
  docs/project/README.md \
  docs/project/state.md \
  docs/project/decisions.md \
  docs/project/questions.md \
  docs/project/updates/update-template.md \
  scripts \
  src \
  tests \
  .bootwitch/project.conf; do
  test -e "$PROJECT_ROOT/$required_path" || {
    printf 'Missing required path: %s\n' "$required_path" >&2
    exit 1
  }
done

grep -q '^BOOTWITCH_SCHEMA=1$' "$PROJECT_ROOT/.bootwitch/project.conf"
