#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_config.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-21
# Version: 0.2.0
# Purpose: Verify complete metadata validation and inert allowlisted reads.
# Arguments: None.
# Output: Config parser success message; assertion errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, rm, awk, wc, grep, cp, ln.
# Reads: lib/bootwitch/config.sh, tests/helpers.sh, and temporary metadata.
# Writes: Temporary configuration fixture; removes its allocated directory on exit.
# Safety: Checks invalid metadata produces no value and command text is never executed.
# Example: bash tests/test_config.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
. "$TEST_DIR/helpers.sh"
. "$PROJECT_ROOT/lib/bootwitch/config.sh"

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-config-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

config_file=$TEST_TMP/project.conf
marker=$TEST_TMP/should-not-exist
cat > "$config_file" <<EOF
BOOTWITCH_SCHEMA=1
PROJECT_NAME=safe-project
TEMPLATE=shell
CREATED_DATE=2026-09-21
BOOTWITCH_VERSION=0.3.0
EOF

value=$(bootwitch_config_get "$config_file" PROJECT_NAME)
test "$value" = safe-project || test_fail 'allowlisted config value was not read'
record=$(bootwitch_config_read "$config_file")
test "$record" = "$(printf '1\tsafe-project\tshell\t2026-09-21\t0.3.0')" || test_fail 'snapshot fields changed order'
assert_not_exists "$marker"

if bootwitch_config_get "$config_file" EVIL >/dev/null 2>&1; then
  test_fail 'non-allowlisted config key was accepted'
fi

cp "$config_file" "$TEST_TMP/valid.conf"
for bad_line in 'PROJECT_NAME=duplicate' 'UNKNOWN=extra' 'BROKEN' 'TEMPLATE=' 'BOOTWITCH_SCHEMA=2'; do
  cp "$TEST_TMP/valid.conf" "$config_file"
  printf '%s\n' "$bad_line" >> "$config_file"
  if bootwitch_config_get "$config_file" PROJECT_NAME > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
    test_fail "invalid metadata was accepted: $bad_line"
  fi
  test ! -s "$TEST_TMP/stdout" || test_fail 'invalid metadata printed a partial value'
done

grep -v '^TEMPLATE=' "$TEST_TMP/valid.conf" > "$config_file"
if bootwitch_config_get "$config_file" PROJECT_NAME > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
  test_fail 'missing metadata field was accepted'
fi
test ! -s "$TEST_TMP/stdout" || test_fail 'missing field printed a value'

cp "$TEST_TMP/valid.conf" "$config_file"
grep -v '^PROJECT_NAME=' "$TEST_TMP/valid.conf" > "$config_file"
printf 'PROJECT_NAME=with\tcontrol\n' >> "$config_file"
if bootwitch_config_get "$config_file" PROJECT_NAME > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
  test_fail 'control-character metadata was accepted'
fi
test ! -s "$TEST_TMP/stdout" || test_fail 'control-character metadata printed a value'

grep -v '^TEMPLATE=' "$TEST_TMP/valid.conf" > "$config_file"
printf 'TEMPLATE=Custom_2\n' >> "$config_file"
test "$(bootwitch_config_get "$config_file" TEMPLATE)" = Custom_2 || test_fail 'writer-compatible template name was rejected'

cp "$TEST_TMP/valid.conf" "$config_file"
cat > "$config_file" <<EOF
BOOTWITCH_SCHEMA=1
PROJECT_NAME=\$(touch "$marker")
TEMPLATE=shell
CREATED_DATE=2026-09-21
BOOTWITCH_VERSION=0.3.0
EOF
if bootwitch_config_get "$config_file" PROJECT_NAME > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
  test_fail 'executable-looking project name was accepted'
fi
assert_not_exists "$marker"
test ! -s "$TEST_TMP/stdout" || test_fail 'unsafe value was printed'

ln -s "$TEST_TMP/valid.conf" "$TEST_TMP/linked.conf"
if bootwitch_config_get "$TEST_TMP/linked.conf" PROJECT_NAME >/dev/null 2>&1; then
  test_fail 'symlink metadata was accepted'
fi

printf 'Config parser tests passed.\n'
