#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_project_info.sh
# Type: test
# Dates: Created: 2026-09-21 | Last Updated: 2026-09-21
# Version: 0.1.0
# Purpose: Verify the CLI reads only validated generated-project metadata.
# Arguments: None.
# Output: Success message on stdout; assertion errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, mkdir, cp, cmp, sed, ln, rm, grep, wc, tr; Bootwitch CLI.
# Reads: Toolkit CLI and disposable generated-project metadata.
# Writes: One allocated temporary project fixture, removed on exit.
# Safety: Exercises corruption only inside the disposable fixture; never executes metadata text.
# Example: bash tests/test_project_info.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
TOOLKIT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
. "$TEST_DIR/helpers.sh"
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-info-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

CLI=$TOOLKIT_ROOT/bin/bootwitch
/bin/bash "$CLI" init inspected-demo --template shell --root "$TEST_TMP/projects" --no-git >/dev/null
project=$TEST_TMP/projects/inspected-demo
config=$project/.bootwitch/project.conf
cp "$config" "$TEST_TMP/valid.conf"

info=$(CDPATH='' cd -- "$project" && /bin/bash "$CLI" project-info)
assert_contains "$info" 'Project: inspected-demo'
assert_contains "$info" 'Template: shell'
assert_contains "$info" 'Created: '
assert_contains "$info" 'Metadata schema: 1'
assert_contains "$info" 'Bootwitch version: '
test "$(printf '%s\n' "$info" | wc -l | tr -d ' ')" -eq 5 || test_fail 'project info printed unexpected fields'

mkdir -p "$project/src/nested"
nested_info=$(CDPATH='' cd -- "$project/src/nested" && /bin/bash "$CLI" project-info)
test "$nested_info" = "$info" || test_fail 'nested project selection changed metadata'
explicit_info=$(CDPATH='' cd -- / && /bin/bash "$CLI" project-info --project "$project")
test "$explicit_info" = "$info" || test_fail 'explicit project selection changed metadata'
cmp "$config" "$TEST_TMP/valid.conf"

if /bin/bash "$CLI" project-info --project '' > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
  test_fail 'empty project option was accepted'
fi
test ! -s "$TEST_TMP/stdout" || test_fail 'invalid arguments produced stdout'
if /bin/bash "$CLI" project-info --project "$project" extra > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
  test_fail 'extra project-info argument was accepted'
fi
test ! -s "$TEST_TMP/stdout" || test_fail 'extra arguments produced stdout'
if /bin/bash "$CLI" project-info --project "$TEST_TMP/missing" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
  test_fail 'missing project was accepted'
fi
test ! -s "$TEST_TMP/stdout" || test_fail 'missing project produced stdout'

for corruption in duplicate unknown malformed schema empty oversized control; do
  cp "$TEST_TMP/valid.conf" "$config"
  case "$corruption" in
    duplicate) printf 'PROJECT_NAME=impostor\n' >> "$config" ;;
    unknown) printf 'PRIVATE_FIELD=unapproved\n' >> "$config" ;;
    malformed) printf 'NOT_A_PAIR\n' >> "$config" ;;
    schema) sed 's/^BOOTWITCH_SCHEMA=1$/BOOTWITCH_SCHEMA=2/' "$TEST_TMP/valid.conf" > "$config" ;;
    empty) sed 's/^TEMPLATE=shell$/TEMPLATE=/' "$TEST_TMP/valid.conf" > "$config" ;;
    oversized) printf '%4097s\n' x >> "$config" ;;
    control) grep -v '^PROJECT_NAME=' "$TEST_TMP/valid.conf" > "$config"; printf 'PROJECT_NAME=spoof\tname\n' >> "$config" ;;
  esac
  if /bin/bash "$CLI" project-info --project "$project" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
    test_fail "corrupt metadata was accepted: $corruption"
  fi
  test ! -s "$TEST_TMP/stdout" || test_fail "partial metadata output for $corruption"
  grep -q 'bootwitch-config:' "$TEST_TMP/stderr" || test_fail "no config error for $corruption"
done

cp "$TEST_TMP/valid.conf" "$config"
mv "$config" "$TEST_TMP/real.conf"
ln -s "$TEST_TMP/real.conf" "$config"
if /bin/bash "$CLI" project-info --project "$project" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
  test_fail 'symlinked project marker was accepted'
fi
test ! -s "$TEST_TMP/stdout" || test_fail 'symlinked marker produced stdout'

printf 'Project-info tests passed.\n'
