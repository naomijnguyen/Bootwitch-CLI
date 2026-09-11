#!/usr/bin/env bash
# @bootwitch:component
# Name: module_finder
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Find a project module locally or in one optional shared directory.
# Arguments: Source with PROJECT_ROOT set; project_find_module NAME.
# Output: Prints the first matching module path.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+.
# Reads: PROJECT_ROOT/modules and optional BOOTWITCH_SHARED_MODULES directory.
# Writes: None; defines functions when sourced.
# Safety: Validates module names and does not mount, copy, download, or source.
# Example: source modules/module_finder.sh
# @bootwitch:end

# Function: project_find_module
# Purpose: Locate a named .sh module without executing it.
# Arguments: $1 is a module name with or without the .sh suffix.
# Output: Prints a local path first, otherwise an explicitly configured shared path.
# Returns: 0 when found, 1 when absent, or 2 for an invalid name.
# How it works: Check PROJECT_ROOT/modules, then BOOTWITCH_SHARED_MODULES.
# Safety: A narrow filename allowlist prevents path traversal and arbitrary reads.
project_find_module() {
  local module_name=${1%.sh}
  local candidate

  case "$module_name" in
    '' | *[!A-Za-z0-9_-]*) return 2 ;;
  esac

  candidate=$PROJECT_ROOT/modules/$module_name.sh
  if test -f "$candidate" && test ! -L "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if test -n "${BOOTWITCH_SHARED_MODULES:-}"; then
    candidate=$BOOTWITCH_SHARED_MODULES/$module_name.sh
    if test -f "$candidate" && test ! -L "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  return 1
}
