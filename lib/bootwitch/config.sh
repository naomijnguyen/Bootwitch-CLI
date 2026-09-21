#!/usr/bin/env bash
# @bootwitch:component
# Name: lib/bootwitch/config.sh
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-21
# Version: 0.2.0
# Purpose: Validate a complete Bootwitch project record and expose a consistent text snapshot.
# Arguments: Source this module; bootwitch_config_read CONFIG_PATH or bootwitch_config_get CONFIG_PATH KEY.
# Output: One validated record or selected value on stdout; errors on stderr.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, awk, wc.
# Reads: Caller-specified .bootwitch/project.conf.
# Writes: None; defines functions when sourced.
# Safety: Rejects symlink/non-regular files, malformed records, and unapproved keys; never evaluates metadata.
# Example: Loaded by the toolkit or its tests; see function contracts above.
# @bootwitch:end

# Function: bootwitch_config_read
# Purpose: Read one coherent, fully validated project metadata snapshot.
# Arguments: $1 is the fixed project metadata path selected by the caller.
# Output: One tab-separated record in schema, name, template, date, version order.
# Returns: 0 for a valid record, 1 for invalid metadata, 2 for invalid arguments.
# Safety: Values cannot contain tabs or control text; no output precedes validation.
bootwitch_config_read() {
  local config_file
  local config_bytes

  test "$#" -eq 1 || return 2
  config_file=$1

  if test ! -f "$config_file" || test -L "$config_file" || test ! -r "$config_file"; then
    printf 'bootwitch-config: metadata must be a readable regular file\n' >&2
    return 1
  fi
  config_bytes=$(wc -c < "$config_file") || return 1
  if test "$config_bytes" -gt 4096; then
    printf 'bootwitch-config: metadata exceeds 4096 bytes\n' >&2
    return 1
  fi

  LC_ALL=C awk '
    function known(key) {
      return key == "BOOTWITCH_SCHEMA" || key == "PROJECT_NAME" ||
        key == "TEMPLATE" || key == "CREATED_DATE" || key == "BOOTWITCH_VERSION"
    }
    {
      separator = index($0, "=")
      if (separator < 2) { bad = 1; next }
      key = substr($0, 1, separator - 1)
      value = substr($0, separator + 1)
      if (!known(key) || ++seen[key] > 1 || value == "") { bad = 1; next }
      if (key == "BOOTWITCH_SCHEMA" && value != "1") bad = 1
      if (key == "PROJECT_NAME" &&
          (value !~ /^[A-Za-z][A-Za-z0-9._-]*$/ || index(value, "..") > 0)) bad = 1
      if (key == "TEMPLATE" &&
          (value !~ /^[A-Za-z0-9_-][A-Za-z0-9._-]*$/ || index(value, "..") > 0)) bad = 1
      if (key == "CREATED_DATE" &&
          value !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) bad = 1
      if (key == "BOOTWITCH_VERSION" && value !~ /^[0-9][A-Za-z0-9.+_-]*$/) bad = 1
      values[key] = value
    }
    END {
      if (NR != 5 || bad || seen["BOOTWITCH_SCHEMA"] != 1 ||
          seen["PROJECT_NAME"] != 1 || seen["TEMPLATE"] != 1 ||
          seen["CREATED_DATE"] != 1 || seen["BOOTWITCH_VERSION"] != 1) {
        print "bootwitch-config: invalid project metadata" > "/dev/stderr"
        exit 1
      }
      printf "%s\t%s\t%s\t%s\t%s\n", values["BOOTWITCH_SCHEMA"],
        values["PROJECT_NAME"], values["TEMPLATE"], values["CREATED_DATE"],
        values["BOOTWITCH_VERSION"]
    }
  ' "$config_file"
}

# Function: bootwitch_config_get
# Purpose: Read one approved value from a validated project record as text.
# Arguments: $1 config path; $2 one of the five writer-defined metadata keys.
# Output: Prints the selected value on stdout after complete validation.
# Returns: 0 for a valid record/key, 1 for invalid metadata, 2 for invalid arguments/key.
# Safety: Uses one validated snapshot; values are never sourced or evaluated.
bootwitch_config_get() {
  local config_key
  local config_record
  local schema
  local project_name
  local template_name
  local created_date
  local created_with

  test "$#" -eq 2 || return 2
  config_key=$2
  case "$config_key" in
    BOOTWITCH_SCHEMA | PROJECT_NAME | TEMPLATE | CREATED_DATE | BOOTWITCH_VERSION) ;;
    *) return 2 ;;
  esac
  config_record=$(bootwitch_config_read "$1") || return 1
  IFS=$'\t' read -r schema project_name template_name created_date created_with <<< "$config_record"
  case "$config_key" in
    BOOTWITCH_SCHEMA) printf '%s\n' "$schema" ;;
    PROJECT_NAME) printf '%s\n' "$project_name" ;;
    TEMPLATE) printf '%s\n' "$template_name" ;;
    CREATED_DATE) printf '%s\n' "$created_date" ;;
    BOOTWITCH_VERSION) printf '%s\n' "$created_with" ;;
  esac
}
