#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_module_finder.sh
# Type: test
# Dates: Created: 2026-09-21 | Last Updated: 2026-09-21
# Version: 0.1.0
# Purpose: Verify the generated module finder's local-first, lookup-only contract.
# Arguments: None.
# Output: Success message on stdout; assertion failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, mkdir, printf, ln, rm.
# Reads: templates/shell/modules/module_finder.sh and disposable fixture paths.
# Writes: One allocated temporary fixture, removed on exit.
# Safety: Never sources a discovered module or writes to a project checkout.
# Example: bash tests/test_module_finder.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
TOOLKIT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-finder-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

PROJECT_ROOT=$TEST_TMP/project
BOOTWITCH_SHARED_MODULES=$TEST_TMP/shared
mkdir -p "$PROJECT_ROOT/modules" "$BOOTWITCH_SHARED_MODULES"
printf 'local fixture\n' > "$PROJECT_ROOT/modules/example.sh"
printf 'shared fixture\n' > "$BOOTWITCH_SHARED_MODULES/example.sh"
printf 'shared only\n' > "$BOOTWITCH_SHARED_MODULES/remote.sh"

. "$TOOLKIT_ROOT/templates/shell/modules/module_finder.sh"

test "$(project_find_module example)" = "$PROJECT_ROOT/modules/example.sh"
test "$(project_find_module example.sh)" = "$PROJECT_ROOT/modules/example.sh"
test "$(project_find_module remote)" = "$BOOTWITCH_SHARED_MODULES/remote.sh"

for invalid_name in '' ../remote 'nested/remote' '.hidden' 'name with spaces'; do
  if project_find_module "$invalid_name" >/dev/null 2>&1; then
    printf 'Module finder accepted invalid name: %s\n' "$invalid_name" >&2
    exit 1
  fi
done

ln -s "$BOOTWITCH_SHARED_MODULES/remote.sh" "$PROJECT_ROOT/modules/remote.sh"
test "$(project_find_module remote)" = "$BOOTWITCH_SHARED_MODULES/remote.sh"

unset BOOTWITCH_SHARED_MODULES
if project_find_module remote >/dev/null 2>&1; then
  printf 'Module finder followed a symlinked local module.\n' >&2
  exit 1
fi
if project_find_module missing >/dev/null 2>&1; then
  printf 'Module finder found a missing module.\n' >&2
  exit 1
fi

printf 'Module finder tests passed.\n'
