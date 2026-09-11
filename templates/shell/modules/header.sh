#!/usr/bin/env bash
# @bootwitch:component
# Name: header
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Read approved project facts from project.header without running it.
# Wrapper: wrappers/initialize_project.command
# Arguments: Source this module; project_header_get HEADER_PATH KEY.
# Output: Requested header value on stdout when called.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, awk.
# Reads: Caller-specified project.header.
# Writes: None; defines functions when sourced.
# Safety: Uses an explicit key allowlist and never source or eval.
# Example: source modules/header.sh
# @bootwitch:end

# Function: project_header_get
# Purpose: Retrieve one approved project.header value as plain text.
# Arguments: $1 is the header path; $2 is the requested field name.
# Output: Prints the first matching value.
# Returns: 0 when found, 1 when absent, or 2 for an unapproved field.
# How it works: Validate the requested key, then let awk return its text value.
# Safety: Header contents remain data and cannot execute shell commands.
project_header_get() {
  local header_file=$1
  local header_key=$2

  case "$header_key" in
    PROJECT_NAME | PROJECT_SLUG | PROJECT_PURPOSE | PROJECT_TYPE | \
      PROJECT_VERSION | PROJECT_STATUS | PRIMARY_WRAPPER) ;;
    *) return 2 ;;
  esac

  awk -F= -v wanted="$header_key" '
    $1 == wanted && !found {
      value = substr($0, length($1) + 2)
      sub(/\r$/, "", value)
      print value
      found = 1
    }
    END { if (!found) exit 1 }
  ' "$header_file"
}
