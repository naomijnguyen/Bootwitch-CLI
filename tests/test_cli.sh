#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_cli.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.3
# Purpose: Verify CLI inspection, guided creation, dry-run, generated projects, and destination refusal.
# Arguments: None.
# Output: CLI integration success message; failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, rm, grep, cmp, Git, and CLI/generated-test dependencies.
# Reads: bin/bootwitch, tests/helpers.sh, bundled templates, and generated fixtures.
# Writes: Temporary projects including local Git repositories; removes its allocated test directory on exit.
# Safety: Uses a unique temporary root, including paths with spaces; no remote Git operations.
# Example: bash tests/test_cli.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
. "$TEST_DIR/helpers.sh"

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

CLI=$PROJECT_ROOT/bin/bootwitch

list_output=$(/bin/bash "$CLI" list)
assert_contains "$list_output" 'base'
assert_contains "$list_output" 'shell'

templates_output=$(/bin/bash "$CLI" templates)
assert_contains "$templates_output" 'Templates:'
assert_contains "$templates_output" 'wrappers/'
assert_contains "$templates_output" 'modules/'

wizard_output=$(/bin/bash "$CLI" wizard)
assert_contains "$wizard_output" 'Bootwitch'
assert_contains "$wizard_output" 'Default root'

summon_root=$TEST_TMP/summon-root
summon_output=$(printf 'summoned-demo\nshell\n%s\nn\n' "$summon_root" | /bin/bash "$CLI" summon 2>&1)
assert_contains "$summon_output" 'summoning a new project'
assert_contains "$summon_output" 'Created'
assert_exists "$summon_root/summoned-demo/wrappers/hello.command"
assert_not_exists "$summon_root/summoned-demo/.git"

dry_root=$TEST_TMP/dry-run-root
dry_output=$(/bin/bash "$CLI" init preview --root "$dry_root" --dry-run)
assert_contains "$dry_output" 'Would create'
assert_not_exists "$dry_root"

if /bin/bash "$CLI" init '../escape' --root "$TEST_TMP/projects" >/dev/null 2>&1; then
  test_fail 'invalid project name was accepted'
fi

space_root=$TEST_TMP/'projects with spaces'
/bin/bash "$CLI" init base-demo --template base --root "$space_root" --no-git >/dev/null
base_project=$space_root/base-demo
assert_exists "$base_project/README.md"
assert_exists "$base_project/.bootwitch/project.conf"
assert_not_exists "$base_project/.git"
/bin/bash "$base_project/tests/run.sh" >/dev/null

metadata=$(cat "$base_project/.bootwitch/project.conf")
assert_contains "$metadata" 'PROJECT_NAME=base-demo'
assert_contains "$metadata" 'TEMPLATE=base'

/bin/bash "$CLI" init shell-demo --template shell --root "$space_root" >/dev/null
shell_project=$space_root/shell-demo
assert_exists "$shell_project/.git"
assert_exists "$shell_project/modules/log.sh"
assert_exists "$shell_project/wrappers/run.command"
/bin/bash "$shell_project/tests/run.sh" >/dev/null

if /bin/bash "$CLI" init shell-demo --template shell --root "$space_root" >/dev/null 2>&1; then
  test_fail 'existing destination was overwritten'
fi

# Both layers must carry the exact notice; shell README rebuilds preserve it.
cmp "$PROJECT_ROOT/LICENSE" "$PROJECT_ROOT/templates/base/LICENSES/Bootwitch-MIT.txt"
for licensed_project in "$base_project" "$shell_project"; do
  cmp "$PROJECT_ROOT/LICENSE" "$licensed_project/LICENSES/Bootwitch-MIT.txt"
  assert_contains "$(cat "$licensed_project/README.md")" '[Bootwitch MIT license](LICENSES/Bootwitch-MIT.txt)'
done
/bin/bash "$shell_project/wrappers/build_readme.command" >/dev/null
cp "$shell_project/README.md" "$TEST_TMP/licensed-readme.md"
/bin/bash "$shell_project/wrappers/build_readme.command" >/dev/null
cmp "$TEST_TMP/licensed-readme.md" "$shell_project/README.md"
assert_contains "$(cat "$shell_project/README.md")" '[Bootwitch MIT license](LICENSES/Bootwitch-MIT.txt)'
cmp "$PROJECT_ROOT/LICENSE" "$shell_project/LICENSES/Bootwitch-MIT.txt"

printf 'CLI integration tests passed.\n'
