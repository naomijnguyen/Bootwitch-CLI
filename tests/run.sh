#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/run.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.3
# Purpose: Run all toolkit test_*.sh suites and report success.
# Arguments: None.
# Output: Test results and final success message on stdout; failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Python 3; Bash 3.2+, dirname; dependencies of the selected test suites.
# Reads: Sibling test_*.sh files.
# Writes: Delegated tests create and remove disposable projects and fixtures.
# Safety: Stops on a failing test; test suites own their temporary fixtures.
# Example: bash tests/run.sh
# @bootwitch:end

set -euo pipefail
IFS=$'\n\t'

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

for test_file in "$TEST_DIR"/test_*.sh; do
  /bin/bash "$test_file"
done

for test_file in "$TEST_DIR"/test_*.py; do
  python3 -B "$test_file"
done

printf 'All Bootwitch tests passed.\n'
