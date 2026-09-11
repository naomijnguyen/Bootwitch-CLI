#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_config.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.2
# Purpose: Verify allowlisted metadata reads and rejection of executable-looking values.
# Arguments: None.
# Output: Config parser success message; assertion errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, rm, awk, grep.
# Reads: lib/bootwitch/config.sh, tests/helpers.sh, and temporary metadata.
# Writes: Temporary configuration fixture; removes its allocated directory on exit.
# Safety: Checks that command text stored in metadata is never executed.
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
EVIL=\$(touch "$marker")
EOF

value=$(bootwitch_config_get "$config_file" PROJECT_NAME)
test "$value" = safe-project || test_fail 'allowlisted config value was not read'
assert_not_exists "$marker"

if bootwitch_config_get "$config_file" EVIL >/dev/null 2>&1; then
  test_fail 'non-allowlisted config key was accepted'
fi

printf 'Config parser tests passed.\n'
