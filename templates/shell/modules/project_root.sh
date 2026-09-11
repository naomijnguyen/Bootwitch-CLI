#!/usr/bin/env bash
# @bootwitch:component
# Name: project_root
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Find the project boundary from any file or folder inside the project.
# Wrapper: wrappers/initialize_project.command
# Arguments: Source this module; project_find_root [START_PATH], defaulting to the current directory.
# Output: Prints the absolute physical project path.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, dirname.
# Reads: Ancestor directories and .bootwitch/project.conf existence.
# Writes: None; directory resolution runs in subshells.
# Safety: Stops at the filesystem root and accepts only a project marker file.
# Example: source modules/project_root.sh
# @bootwitch:end

# Function: project_find_root
# Purpose: Walk upward until .bootwitch/project.conf identifies the project.
# Arguments: $1 is a starting file or directory; defaults to the current folder.
# Output: Prints the discovered absolute project path.
# Returns: 0 when found or 1 when no Bootwitch project marker can be found.
# How it works: Convert the start to a physical directory, inspect it, then move
# to its parent until the marker appears or the filesystem root is reached.
# Safety: Performs only directory and file-existence checks; it changes no state.
project_find_root() {
  local start_path=${1:-$PWD}
  local current_dir
  local parent_dir

  if test -f "$start_path"; then
    start_path=$(dirname -- "$start_path")
  fi

  current_dir=$(CDPATH='' cd -P -- "$start_path" 2>/dev/null && pwd) || {
    printf 'project-root: cannot inspect starting path: %s\n' "$start_path" >&2
    return 1
  }

  while :; do
    if test -f "$current_dir/.bootwitch/project.conf"; then
      printf '%s\n' "$current_dir"
      return 0
    fi

    test "$current_dir" != / || break
    parent_dir=$(dirname -- "$current_dir")
    test "$parent_dir" != "$current_dir" || break
    current_dir=$parent_dir
  done

  printf 'project-root: no .bootwitch/project.conf found above %s\n' "$start_path" >&2
  return 1
}
