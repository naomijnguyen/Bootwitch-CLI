#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/helpers.sh
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-21
# Version: 0.1.2
# Purpose: Provide shared assertions for Bootwitch integration tests.
# Arguments: Source this module; assertion functions accept paths or expected text.
# Output: Failure messages on stderr; successful assertions are silent.
# Returns: Assertions return 0 on success; failure exits the calling shell with status 1.
# Dependencies: Bash 3.2+, grep.
# Reads: Paths and text supplied to assertions.
# Writes: None; defines functions and sets assertion variables when called.
# Safety: Assertions inspect data; test_fail exits the caller with status 1.
# Example: source tests/helpers.sh
# @bootwitch:end

test_fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_exists() {
  test -e "$1" || test_fail "expected path to exist: $1"
}

assert_not_exists() {
  test ! -e "$1" || test_fail "expected path not to exist: $1"
}

assert_contains() {
  haystack=$1
  needle=$2
  grep -F -q -- "$needle" <<< "$haystack" || test_fail "expected output to contain: $needle"
}
