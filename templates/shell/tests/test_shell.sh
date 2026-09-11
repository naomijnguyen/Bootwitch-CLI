#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_shell.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.2.0
# Purpose: Exercise universal headers, the shell demo, script generator, root discovery, and permission boundaries.
# Arguments: None.
# Output: Mostly silent on success; delegated errors on failure.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, grep, sed, mkdir, mv, mktemp, cp, rm, find, and project wrapper/generator dependencies.
# Reads: Project scripts, wrappers, modules, README, and metadata.
# Writes: Disposable copied project only, removed on exit.
# Safety: All mutations occur in an owned temporary copy; the original project is read-only.
# Example: bash tests/test_shell.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

PROJECT_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TEST_SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-shell-test.XXXXXX")
trap 'rm -rf "$TEST_SANDBOX"' EXIT
trap 'exit 1' HUP INT TERM
cp -R "$PROJECT_ROOT/." "$TEST_SANDBOX/"
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_SANDBOX" && pwd)
# Copied symlinks could point back into the original project or outside it.
copied_links=$(find "$PROJECT_ROOT" -type l -print)
if test -n "$copied_links"; then
  printf 'Shell mutation tests require a copy without symlinks.\n' >&2
  exit 1
fi
# Reserve an unused fixture name even when the source contains earlier samples.
fixture_name=sample-task
while test -e "$PROJECT_ROOT/scripts/$fixture_name.sh" || test -L "$PROJECT_ROOT/scripts/$fixture_name.sh" ||
      test -e "$PROJECT_ROOT/src/nested/tools/$fixture_name.sh" || test -L "$PROJECT_ROOT/src/nested/tools/$fixture_name.sh"; do
  fixture_name=${fixture_name}-test
done

# Function: check_universal_header
# Purpose: Confirm one bundled shell file starts with the complete shared header.
# Arguments: $1 is a generated-project .sh or .command path.
# Output: Assertion failures only.
# Returns: 0 when every required field is populated.
check_universal_header() {
  local shell_file=$1
  local metadata_field

  test "$(sed -n '1p' "$shell_file")" = '#!/usr/bin/env bash'
  test "$(sed -n '2p' "$shell_file")" = '# @bootwitch:component'
  for metadata_field in Name Type Dates Version Purpose Arguments Output Returns Dependencies Reads Writes Safety Example; do
    grep -q "^# $metadata_field: ." "$shell_file"
  done
}

output=$(CDPATH='' cd -- / && /bin/bash "$PROJECT_ROOT/wrappers/run.command" 2>&1)
printf '%s\n' "$output" | grep -q 'Demonstration report was verified.'
printf '%s\n' "$output" | grep -q "Report: $PROJECT_ROOT/output/run-report.txt"
test -f "$PROJECT_ROOT/output/run-report.txt"
grep -q '^Project: {{PROJECT_NAME}}$' "$PROJECT_ROOT/output/run-report.txt"
test -f "$PROJECT_ROOT/logs/project.log"

hello_output=$(/bin/bash "$PROJECT_ROOT/wrappers/hello.command")
printf '%s\n' "$hello_output" | grep -q 'Hello from Bootwitch.'
printf '%s\n' "$hello_output" | grep -q 'Welcome to the coven.'

for shell_file in "$PROJECT_ROOT"/scripts/*.sh "$PROJECT_ROOT"/src/*.sh "$PROJECT_ROOT"/modules/*.sh "$PROJECT_ROOT"/tests/*.sh; do
  /bin/bash -n "$shell_file"
  check_universal_header "$shell_file"
done
for wrapper_file in "$PROJECT_ROOT"/wrappers/*.command; do
  /bin/bash -n "$wrapper_file"
  check_universal_header "$wrapper_file"
done

# Initialization fills the marked README section from project.header and the
# component annotations without altering the human-authored sections.
/bin/bash "$PROJECT_ROOT/wrappers/initialize_project.command" >/dev/null 2>&1
grep -q '^## Project overview$' "$PROJECT_ROOT/README.md"
grep -q '^## Component reference$' "$PROJECT_ROOT/README.md"
grep -q 'hello.command' "$PROJECT_ROOT/README.md"
grep -q 'make_executable.command' "$PROJECT_ROOT/README.md"
grep -q 'project_create_report' "$PROJECT_ROOT/README.md"

# The project-local generator should create one documented executable and must
# refuse to replace it when called again with the same name.
generator_output=$(/bin/bash "$PROJECT_ROOT/scripts/new-script.sh" "$fixture_name" scripts)
printf '%s\n' "$generator_output" | grep -q "Created scripts/${fixture_name}.sh"
test -x "$PROJECT_ROOT/scripts/${fixture_name}.sh"
grep -q '# Function: main' "$PROJECT_ROOT/scripts/${fixture_name}.sh"
grep -q '^# @bootwitch:component$' "$PROJECT_ROOT/scripts/${fixture_name}.sh"
check_universal_header "$PROJECT_ROOT/scripts/${fixture_name}.sh"
grep -Fxq 'set -e' "$PROJECT_ROOT/scripts/${fixture_name}.sh"
grep -Fxq 'set -u' "$PROJECT_ROOT/scripts/${fixture_name}.sh"
grep -Fxq 'set -o pipefail' "$PROJECT_ROOT/scripts/${fixture_name}.sh"
if grep -q '^IFS=' "$PROJECT_ROOT/scripts/${fixture_name}.sh"; then
  printf 'Generated script overrides IFS globally.\n' >&2
  exit 1
fi
if grep -q '{{SCRIPT_NAME}}' "$PROJECT_ROOT/scripts/${fixture_name}.sh" || \
  grep -q '{{SCRIPT_CREATED''_DATE}}' "$PROJECT_ROOT/scripts/${fixture_name}.sh"; then
  printf 'Generated script still contains unresolved script tokens.\n' >&2
  exit 1
fi
if /bin/bash "$PROJECT_ROOT/scripts/new-script.sh" "$fixture_name" scripts >/dev/null 2>&1; then
  printf 'Generator overwrote an existing script.\n' >&2
  exit 1
fi

# A generated script remains runnable after moving deeper inside the project.
mkdir -p "$PROJECT_ROOT/src/nested/tools"
mv "$PROJECT_ROOT/scripts/${fixture_name}.sh" "$PROJECT_ROOT/src/nested/tools/${fixture_name}.sh"
moved_output=$(CDPATH='' cd -- / && /bin/bash "$PROJECT_ROOT/src/nested/tools/${fixture_name}.sh" 2>&1)
printf '%s\n' "$moved_output" | grep -q "${fixture_name} started"

# The finder reports project modules without sourcing or changing them.
. "$PROJECT_ROOT/modules/module_finder.sh"
found_module=$(project_find_module log)
test "$found_module" = "$PROJECT_ROOT/modules/log.sh"

# The permission wrapper refuses paths outside the project.
if /bin/bash "$PROJECT_ROOT/wrappers/make_executable.command" ../outside.sh >/dev/null 2>&1; then
  printf 'Permission wrapper accepted an outside-project path.\n' >&2
  exit 1
fi
