#!/usr/bin/env bash
# @bootwitch:component
# Name: {{SCRIPT_NAME}}.sh
# Type: script
# Dates: Created: {{SCRIPT_CREATED_DATE}} | Last Updated: {{SCRIPT_UPDATED_DATE}}
# Version: 0.1.0
# Purpose: Prepare runtime folders and log workflow start.
# Arguments: None.
# Output: Timestamped stderr messages.
# Returns: 0 success; nonzero failure.
# Dependencies: Bash 3.2+, dirname, mkdir, date; modules/paths.sh, modules/log.sh.
# Reads: .bootwitch/project.conf (root marker).
# Writes: logs/, cache/, temp/, output/; logs/project.log.
# Safety: Uses the discovered root; stops if absent.
# Example: bash {{SCRIPT_AREA}}/{{SCRIPT_NAME}}.sh
# @bootwitch:end

# Bash safety settings are written separately so each guardrail stays visible:
# -e stops after an unhandled command failure.
# -u rejects unset variables.
# pipefail reports a failure from any command in a pipeline.
set -e
set -u
set -o pipefail

# Resolve from this file rather than the caller's current working directory.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# @bootwitch:function
# Name: find_root_for_this_script
# Purpose: Keep this script working if it moves deeper inside the same project.
# Arguments: None; the search begins at SCRIPT_DIR.
# Output: Prints the directory containing .bootwitch/project.conf.
# Returns: 0 when found or 1 after safely reaching the filesystem root.
# Reads: Parent-directory metadata and the project-root marker.
# Writes: None.
# Safety: Stops at the filesystem root and never changes directories in the caller.
# @bootwitch:end
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

# @bootwitch:function
# Name: main
# Purpose: Provide one obvious starting point for this script's workflow.
# Arguments: Receives command-line arguments; the starter does not interpret them.
# Output: A timestamped start message on stderr and in the runtime log.
# Returns: 0 on success; strict mode stops the script on unhandled setup or logging failures.
# Reads: The discovered project-root marker and current UTC time.
# Writes: Runtime directories and an appended logs/project.log entry.
# Safety: Uses project-relative runtime paths; does not collect host observations.
# @bootwitch:end
main() {
  project_set_paths "$PROJECT_ROOT"
  project_prepare_directories
  project_log info "{{SCRIPT_NAME}} started"
}

# Quoted "$@" keeps each caller argument intact, including spaces.
main "$@"
