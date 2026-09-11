#!/usr/bin/env bash
# @bootwitch:component
# Name: {{SCRIPT_NAME}}.sh
# Type: script
# Dates: Created: {{SCRIPT_CREATED_DATE}} | Last Updated: {{SCRIPT_UPDATED_DATE}}
# Version: 0.1.0
# Purpose: Prepare project runtime directories and log the start of a custom workflow.
# Arguments: None.
# Output: Progress messages to stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, modules/paths.sh, modules/log.sh
# Reads: Project-root marker .bootwitch/project.conf.
# Writes: Standard runtime directories and logs/project.log.
# Safety: Derives runtime paths from the discovered project root.
# Example: bash {{SCRIPT_AREA}}/{{SCRIPT_NAME}}.sh
# @bootwitch:end

# Stop on an unhandled error (-e), undefined variable (-u), or failed pipeline
# stage (pipefail). A newline/tab IFS avoids accidental splitting on spaces.
set -euo pipefail
IFS=$'\n\t'

# Resolve from this file rather than the caller's current working directory.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Function: find_root_for_this_script
# Purpose: Keep this script working if it moves deeper inside the same project.
# Arguments: None; the search begins at SCRIPT_DIR.
# Output: Prints the directory containing .bootwitch/project.conf.
# Returns: 0 when found or 1 after safely reaching the filesystem root.
find_root_for_this_script() {
  local search_dir=$SCRIPT_DIR
  local parent_dir

  while :; do
    if test -f "$search_dir/.bootwitch/project.conf"; then
      printf '%s\n' "$search_dir"
      return 0
    fi
    test "$search_dir" != / || break
    parent_dir=$(dirname -- "$search_dir")
    test "$parent_dir" != "$search_dir" || break
    search_dir=$parent_dir
  done

  printf '{{SCRIPT_NAME}}: cannot find the Bootwitch project root\n' >&2
  return 1
}

PROJECT_ROOT=$(find_root_for_this_script)

# Load the logging helper from the discovered project, not a personal path.
. "$PROJECT_ROOT/modules/paths.sh"
. "$PROJECT_ROOT/modules/log.sh"

# Function: main
# Purpose: Provide one obvious starting point for this script's workflow.
# Arguments: Receives all command-line arguments passed to the script.
# Output: TODO - document stdout, stderr, and files this script creates.
# Returns: 0 on success; document intentional non-zero statuses here.
# How it works: Replace the starter log line with small, named function calls.
main() {
  project_set_paths "$PROJECT_ROOT"
  project_prepare_directories
  project_log info "{{SCRIPT_NAME}} started"
}

# Quoted "$@" keeps each caller argument intact, including spaces.
main "$@"
