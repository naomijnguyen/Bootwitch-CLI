#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_module_finder.sh
# Type: test
# Dates: Created: 2026-09-21 | Last Updated: 2026-09-21
# Version: 0.1.0
# Purpose: Verify local-first module lookup and manifest-backed capability discovery.
# Arguments: None.
# Output: Success message on stdout; assertion failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, mkdir, printf, ln, rm, grep.
# Reads: shell module catalog/finder and disposable fixture paths.
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
printf 'example|Example local module|project_example\n' > "$PROJECT_ROOT/modules/manifest.psv"

. "$TOOLKIT_ROOT/templates/shell/modules/module_finder.sh"

test "$(project_find_module example)" = "$PROJECT_ROOT/modules/example.sh"
test "$(project_find_module example.sh)" = "$PROJECT_ROOT/modules/example.sh"
test "$(project_find_module remote)" = "$BOOTWITCH_SHARED_MODULES/remote.sh"
test "$(project_list_modules)" = "$(printf 'example\tExample local module')"
test "$(project_find_module_for project_example)" = "$PROJECT_ROOT/modules/example.sh"
if project_find_module_for project_missing >/dev/null 2>&1; then
  printf 'Manifest lookup found an unlisted function.\n' >&2
  exit 1
fi

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

# The shipped manifest covers each actual generated shell module and names
# functions that are declared in that module, without sourcing any module.
PROJECT_ROOT=$TOOLKIT_ROOT/templates/shell
for module_path in "$PROJECT_ROOT"/modules/*.sh; do
  module_name=${module_path##*/}
  module_name=${module_name%.sh}
  project_list_modules | grep -q "^$module_name$(printf '\t')" || {
    printf 'Module missing from shipped manifest: %s\n' "$module_name" >&2
    exit 1
  }
done
while IFS='|' read -r module_name summary functions; do
  case $module_name in \#* | '') continue ;; esac
  test -n "$summary"
  IFS=, read -r -a exported_functions <<< "$functions"
  for function_name in "${exported_functions[@]}"; do
    grep -Eq "^${function_name}\\(\\) [({]" "$PROJECT_ROOT/modules/$module_name.sh" || {
      printf 'Manifest claims an absent function: %s in %s\n' "$function_name" "$module_name" >&2
      exit 1
    }
    test "$(project_find_module_for "$function_name")" = "$PROJECT_ROOT/modules/$module_name.sh"
  done
done < "$PROJECT_ROOT/modules/manifest.psv"
test "$(project_find_module_for project_make_executable)" = "$PROJECT_ROOT/modules/permissions.sh"
test "$(project_find_module_for project_build_readme)" = "$PROJECT_ROOT/modules/documentation.sh"

PROJECT_ROOT=$TEST_TMP/project
printf 'example|Example local module|project_example\nmissing|Bad|project_bad\n' > "$PROJECT_ROOT/modules/manifest.psv"
if project_list_modules > "$TEST_TMP/listing"; then
  printf 'Malformed manifest was accepted.\n' >&2
  exit 1
fi
test ! -s "$TEST_TMP/listing" || {
  printf 'Partial manifest listing escaped before validation.\n' >&2
  exit 1
}
if project_find_module_for project_example >/dev/null 2>&1; then
  printf 'Manifest lookup ignored a malformed later row.\n' >&2
  exit 1
fi

printf 'Module finder tests passed.\n'
