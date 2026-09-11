#!/usr/bin/env bash
# @bootwitch:component
# Name: paths
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Define and prepare standard folders beneath a verified project root.
# Wrapper: wrappers/initialize_project.command
# Arguments: Source this module; project_set_paths ROOT, then project_prepare_directories.
# Output: No terminal output on success; sets path variables when called.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, mkdir.
# Reads: ROOT/.bootwitch/project.conf existence.
# Writes: When called, sets project path variables and creates logs/cache/temp/output directories.
# Safety: Refuses roots without .bootwitch/project.conf and never uses cwd.
# Example: source modules/paths.sh
# @bootwitch:end

# Function: project_set_paths
# Purpose: Give commonly used project folders clear, reusable variable names.
# Arguments: $1 is the absolute project root returned by project_find_root.
# Output: Sets PROJECT_ROOT, PROJECT_LOG_DIR, PROJECT_CACHE_DIR,
# PROJECT_TEMP_DIR, PROJECT_OUTPUT_DIR, and PROJECT_LOG_FILE.
# Returns: 0 when the root is verified or 1 when its marker is missing.
# How it works: Verify the marker, then build every path from the same root.
# Safety: Does not create anything and accepts no independent output paths.
project_set_paths() {
  test "$#" -eq 1 || return 2
  test -f "$1/.bootwitch/project.conf" || {
    printf 'paths: invalid project root: %s\n' "$1" >&2
    return 1
  }

  PROJECT_ROOT=$1
  PROJECT_LOG_DIR=$PROJECT_ROOT/logs
  PROJECT_CACHE_DIR=$PROJECT_ROOT/cache
  PROJECT_TEMP_DIR=$PROJECT_ROOT/temp
  PROJECT_OUTPUT_DIR=$PROJECT_ROOT/output
  export PROJECT_LOG_FILE=$PROJECT_LOG_DIR/project.log
}

# Function: project_prepare_directories
# Purpose: Ensure the standard writable project folders exist.
# Arguments: None; project_set_paths must run first.
# Output: Creates missing directories and prints nothing.
# Returns: mkdir's status.
# How it works: One mkdir -p call creates all four paths idempotently.
# Safety: Every destination was derived from the verified PROJECT_ROOT.
project_prepare_directories() {
  : "${PROJECT_ROOT:?project_set_paths must run first}"
  mkdir -p "$PROJECT_LOG_DIR" "$PROJECT_CACHE_DIR" "$PROJECT_TEMP_DIR" "$PROJECT_OUTPUT_DIR"
}
