#!/usr/bin/env bash
# @bootwitch:component
# Name: module_finder
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-21
# Version: 0.2.0
# Purpose: Locate shell modules by name or exported function using a local catalog.
# Arguments: Source with PROJECT_ROOT set; project_find_module NAME, project_list_modules, or project_find_module_for FUNCTION.
# Output: Matching module path or catalog rows; no module body is executed.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+.
# Reads: PROJECT_ROOT/modules/manifest.psv, local modules, and optional BOOTWITCH_SHARED_MODULES directory.
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

# Function: project_list_modules
# Purpose: Show each cataloged local module and its short purpose.
# Arguments: None.
# Output: One tab-separated name and purpose per line.
# Returns: 0 for a valid catalog, 1 when absent, 2 when malformed.
project_list_modules() {
  local manifest=$PROJECT_ROOT/modules/manifest.psv
  local name purpose functions extra listing=''
  test -f "$manifest" && test ! -L "$manifest" || return 1
  while IFS='|' read -r name purpose functions extra || test -n "$name$purpose$functions$extra"; do
    case $name in \#* | '') continue ;; esac
    case $name in *[!A-Za-z0-9_-]*) return 2 ;; esac
    test -n "$purpose" && test -n "$functions" && test -z "$extra" || return 2
    case $functions in *[!A-Za-z0-9_,]* | ,* | *, | *,,*) return 2 ;; esac
    test -f "$PROJECT_ROOT/modules/$name.sh" && test ! -L "$PROJECT_ROOT/modules/$name.sh" || return 2
    listing=$listing$name$'\t'$purpose$'\n'
  done < "$manifest"
  printf '%s' "$listing"
}

# Function: project_find_module_for
# Purpose: Find a cataloged local module by the exact function it exports.
# Arguments: $1 is a function name such as project_make_executable.
# Output: One regular, non-symlink local module path; never sources it.
# Returns: 0 when found, 1 when absent, 2 for invalid input or catalog.
project_find_module_for() {
  local requested=${1:-}
  local manifest=$PROJECT_ROOT/modules/manifest.psv
  local name purpose functions extra candidate found=''
  case $requested in '' | *[!A-Za-z0-9_]*) return 2 ;; esac
  test -f "$manifest" && test ! -L "$manifest" || return 1
  while IFS='|' read -r name purpose functions extra || test -n "$name$purpose$functions$extra"; do
    case $name in \#* | '') continue ;; esac
    case $name in *[!A-Za-z0-9_-]*) return 2 ;; esac
    test -n "$purpose" && test -n "$functions" && test -z "$extra" || return 2
    case $functions in *[!A-Za-z0-9_,]* | ,* | *, | *,,*) return 2 ;; esac
    candidate=$PROJECT_ROOT/modules/$name.sh
    test -f "$candidate" && test ! -L "$candidate" || return 2
    case ,$functions, in *,"$requested",*)
      test -z "$found" || return 2
      found=$candidate ;;
    esac
  done < "$manifest"
  test -n "$found" || return 1
  printf '%s\n' "$found"
}
