#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/run.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.3
# Purpose: Run all generated project test_*.sh suites.
# Arguments: None.
# Output: Delegated test output and final project success message.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname; dependencies of the selected test suites.
# Reads: Sibling test_*.sh files.
# Writes: Delegated tests may create project runtime files and fixtures.
# Safety: Stops on failure; bundled shell mutation tests use a disposable copy; custom suites control their own writes.
# Example: bash tests/run.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

for test_file in "$TEST_DIR"/test_*.sh; do
  test -e "$test_file" || continue
  /bin/bash "$test_file"
done

printf 'All project tests passed.\n'
