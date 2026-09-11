#!/usr/bin/env bash
# @bootwitch:component
# Name: lib/bootwitch/config.sh
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Read allowlisted Bootwitch project metadata as plain text.
# Arguments: Source this module; bootwitch_config_get CONFIG_PATH KEY.
# Output: The first matching value on stdout when called.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, awk.
# Reads: Caller-specified .bootwitch/project.conf.
# Writes: None; defines functions when sourced.
# Safety: Rejects unapproved keys; never sources or evaluates metadata.
# Example: Loaded by the toolkit or its tests; see function contracts above.
# @bootwitch:end

# Function: bootwitch_config_get
# Purpose: Read one approved value from .bootwitch/project.conf as plain text.
# Arguments: $1 is the config path; $2 is the metadata key to retrieve.
# Output: Prints the first matching value to stdout.
# Returns: 0 when found, 1 when missing, or 2 when the key is not allowlisted.
# How it works: awk finds the requested key and returns its text after the first
# equals sign. The shell never runs the line it reads.
# Safety: Only known metadata keys are accepted, and the config is never sourced
# or passed to eval.
bootwitch_config_get() {
  config_file=$1
  config_key=$2

  case "$config_key" in
    BOOTWITCH_SCHEMA | PROJECT_NAME | TEMPLATE | CREATED_DATE | BOOTWITCH_VERSION) ;;
    *) return 2 ;;
  esac

  awk -F= -v wanted="$config_key" '
    $1 == wanted && !found {
      value = substr($0, length($1) + 2)
      sub(/\r$/, "", value)
      print value
      found = 1
    }
    END { if (!found) exit 1 }
  ' "$config_file"
}
